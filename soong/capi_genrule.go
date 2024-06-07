package capi

import (
	"fmt"
	"io"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/google/blueprint"
	"github.com/google/blueprint/bootstrap"
	"github.com/google/blueprint/proptools"

	"android/soong/android"
)

var (
	// Create a context for build rule output from this package
	pctx = android.NewPackageContext("android/soong/external/capi")

	// Used by gensrcs when there is more than 1 shard to merge the outputs
	// of each shard into a zip file.
	gensrcsMerge = pctx.AndroidStaticRule("gensrcsMerge", blueprint.RuleParams{
		Command:        "${soongZip} -o ${tmpZip} @${tmpZip}.rsp && ${zipSync} -d ${genDir} ${tmpZip}",
		CommandDeps:    []string{"${soongZip}", "${zipSync}"},
		Rspfile:        "${tmpZip}.rsp",
		RspfileContent: "${zipArgs}",
	}, "tmpZip", "genDir", "zipArgs")
)

func init() {
	RegisterGenruleBuildComponents(android.InitRegistrationContext)
}

func RegisterGenruleBuildComponents(ctx android.RegistrationContext) {
	ctx.RegisterModuleType("capi_genrule", capiCodeGenModuleFactory)

	ctx.FinalDepsMutators(func(ctx android.RegisterMutatorsContext) {
		ctx.BottomUp("capi_genrule_tool_deps", toolDepsMutator).Parallel()
	})

}

type SourceFileGenerator interface {
	GeneratedSourceFiles() android.Paths
	GeneratedHeaderDirs() android.Paths
	GeneratedDeps() android.Paths
}

// Alias for android.HostToolProvider
// Deprecated: use android.HostToolProvider instead.
type HostToolProvider interface {
	android.HostToolProvider
}

type hostToolDependencyTag struct {
	blueprint.BaseDependencyTag
	label string
}

// TODO figure out how to make this a submodule, and populate it directly from Android.bp
type capiDestDirs struct {
	Core_skeleton string
	Core_common   string
	Core_proxy    string
	Core_stub     string
	Someip_common string
	Someip_proxy  string
	Someip_stub   string
}
type generatorProperties struct {
	// The command to run on one or more input files. Cmd supports substitution of a few variables
	//
	// Available variables for substitution:
	//
	//  $(location): the path to the first entry in tools or tool_files
	//  $(location <label>): the path to the tool, tool_file, input or output with name <label>
	//  $(in): one or more input files
	//  $(out): a single output file
	//  $(depfile): a file to which dependencies will be written, if the depfile property is set to true
	//  $(genDir): the sandbox directory for this tool; contains $(out)
	//  $(fidl): The fidl file to use
	//  $(fdepl): The fdepl file to use
	//  $$: a literal $
	Cmd *string

	// Enable reading a file containing dependencies in gcc format after the command completes
	Depfile *bool

	// name of the modules (if any) that produces the host executable.   Leave empty for
	// prebuilts or scripts that do not need a module to build them.
	Tools []string

	// Local file that is used as the tool
	Tool_files []string `android:"path"`

	// List of directories to export generated headers from
	Export_include_dirs []string

	// list of files the fidl/fdepl files are dependant on - not to be confused with depFiles
	Deps []string `android:"path,arch_variant"`

	// Addition output files.  Similar to `out`, but accepts $(coreCommon), etc
	Additional_out []string

	// input files to exclude
	Exclude_srcs []string `android:"path,arch_variant"`

	Fidl  string `android:"path,arch_variant"`
	Fdepl string `android:"path,arch_variant"`

	// CommonAPI interfaces to generate
	Interfaces []string

	// Versions of CommonAPI interfaces
	Versions []string

	// Verbosity level of CommonAPI generator
	Generator_verbosity string

	// Deprecated: Calling the generators has been re-factored such that this is
	// no longer required, thus this option no longer does anything.
	Core_rerun_with_fdepl bool

	// Generation location passed to generator for core skeleton files
	Dest_core_skeleton string
	Dest_core_common   string
	Dest_core_proxy    string
	Dest_core_stub     string
	Dest_someip_common string
	Dest_someip_proxy  string
	Dest_someip_stub   string

	// Do not generate the stub adapter
	Disable_service_stub bool
	// Do not generate the proxy
	Disable_proxy bool
}

type Module struct {
	android.ModuleBase
	android.DefaultableModuleBase
	android.BazelModuleBase
	android.ApexModuleBase

	// For other packages to make their own genrules with extra
	// properties
	Extra interface{}
	android.ImageInterface

	properties generatorProperties

	// Structure to contain the destination directories
	Dest_dirs capiDestDirs

	// For the different tasks that genrule and gensrc generate. genrule will
	// generate 1 task, and gensrc will generate 1 or more tasks based on the
	// number of shards the input files are sharded into.
	taskGenerator taskFunc

	rule        blueprint.Rule
	rawCommands []string

	exportedIncludeDirs android.Paths

	// Each module has a list of files it outputs, that can be used by other
	// modules. Store the list of paths here for easy reference.
	outputFiles android.Paths
	outputDeps  android.Paths

	subName string
	subDir  string

	// Collect the module directory for IDE info in java/jdeps.go.
	modulePaths []string
}

type taskFunc func(ctx android.ModuleContext, rawCommand string, dest_dirs capiDestDirs, interfaces []string, versions []float32, srcFiles android.Paths, outFiles []string, disable_stub bool, disable_proxy bool) []generateTask

type generateTask struct {
	in         android.Paths
	out        android.WritablePaths
	depFile    android.WritablePath
	copyTo     android.WritablePaths // For gensrcs to set on gensrcsMerge rule.
	genDir     android.WritablePath
	extraTools android.Paths // dependencies on tools used by the generator

	cmd string
	// For gensrsc sharding.
	shard  int
	shards int
}

func (g *Module) GeneratedSourceFiles() android.Paths {
	var impls android.Paths
	for _, p := range g.outputFiles {
		if p.Ext() == ".cpp" {
			impls = append(impls, p)
		}
	}

	return impls
}

func (g *Module) Srcs() android.Paths {
	// Maybe reuse GeneratedSourceFiles()
	var impls android.Paths
	for _, p := range g.outputFiles {
		if p.Ext() == ".cpp" {
			impls = append(impls, p)
		}
	}
	return append(android.Paths{}, impls...)
}

func (g *Module) GeneratedHeaderDirs() android.Paths {
	return g.exportedIncludeDirs
}

func (g *Module) GeneratedDeps() android.Paths {
	return g.outputDeps
}

func append_unique(list []string, val string) []string {
	// Append a value to a slice _if_ the value is unique
	for _, a := range list {
		if a == val {
			return list
		}
	}
	return append(list, val)
}

func toolDepsMutator(ctx android.BottomUpMutatorContext) {
	// This gets called thousands of times
	if g, ok := ctx.Module().(*Module); ok {
		// Matt: This doesn't seem like ths right place to inject these defaults.
		// Moreover, it appears to get called thousands of times.  Maybe the
		// "extraTools" would be a better place?
		// Also, this introduces a string coupling to the delcaration of the
		// CommonAPI generation tools.  If these tools are renamed, these next two
		// lines will fail.
		g.properties.Tools = append_unique(g.properties.Tools, "commonapi.generator.core")
		g.properties.Tools = append_unique(g.properties.Tools, "commonapi.generator.someip")

		for _, tool := range g.properties.Tools {
			tag := hostToolDependencyTag{label: tool}
			if m := android.SrcIsModule(tool); m != "" {
				tool = m
			}
			ctx.AddFarVariationDependencies(ctx.Config().BuildOSTarget.Variations(), tag, tool)
		}
	}
}

func (g *Module) GenerateAndroidBuildActions(ctx android.ModuleContext) {
	g.subName = ctx.ModuleSubDir()

	// Collect the module directory for IDE info in java/jdeps.go.
	g.modulePaths = append(g.modulePaths, ctx.ModuleDir())

	// Default command.
	input_or_default := func(input_val string, default_val string) string {
		var dir string
		if input_val == "" {
			dir = default_val
		} else {
			dir = input_val
		}
		return dir
	}
	g.Dest_dirs.Core_skeleton = input_or_default(g.properties.Dest_core_skeleton, "core/skeleton")
	g.Dest_dirs.Core_common = input_or_default(g.properties.Dest_core_common, "core/common")
	g.Dest_dirs.Core_proxy = input_or_default(g.properties.Dest_core_proxy, "core/proxy")
	g.Dest_dirs.Core_stub = input_or_default(g.properties.Dest_core_stub, "core/stub")
	g.Dest_dirs.Someip_common = input_or_default(g.properties.Dest_someip_common, "someip/common")
	g.Dest_dirs.Someip_proxy = input_or_default(g.properties.Dest_someip_proxy, "someip/proxy")
	g.Dest_dirs.Someip_stub = input_or_default(g.properties.Dest_someip_stub, "someip/stub")

	g.properties.Export_include_dirs = append(g.properties.Export_include_dirs, []string{
		g.Dest_dirs.Core_skeleton,
		g.Dest_dirs.Core_common,
		g.Dest_dirs.Core_proxy,
		g.Dest_dirs.Core_stub,
		g.Dest_dirs.Someip_common,
		g.Dest_dirs.Someip_proxy,
		g.Dest_dirs.Someip_stub}...)

	// Expand directories in outputs
	for i, out_name := range g.properties.Additional_out {
		expanded_name, _ := android.Expand(out_name, func(name string) (string, error) {
			switch name {
			case "coreSkeleton":
				return g.Dest_dirs.Core_skeleton, nil
			case "coreCommon":
				return g.Dest_dirs.Core_common, nil
			case "coreProxy":
				return g.Dest_dirs.Core_proxy, nil
			case "coreStub":
				return g.Dest_dirs.Core_stub, nil
			case "someipCommon":
				return g.Dest_dirs.Someip_common, nil
			case "someipProxy":
				return g.Dest_dirs.Someip_proxy, nil
			case "someipStub":
				return g.Dest_dirs.Someip_stub, nil
			}
			return out_name, nil
		})
		g.properties.Additional_out[i] = expanded_name
	}

	if len(g.properties.Export_include_dirs) > 0 {
		for _, dir := range g.properties.Export_include_dirs {
			g.exportedIncludeDirs = append(g.exportedIncludeDirs,
				android.PathForModuleGen(ctx, g.subDir, dir))
		}
	} else {
		g.exportedIncludeDirs = append(g.exportedIncludeDirs, android.PathForModuleGen(ctx, g.subDir))
	}

	locationLabels := map[string]location{}
	firstLabel := ""

	addLocationLabel := func(label string, loc location) {
		if firstLabel == "" {
			firstLabel = label
		}
		if _, exists := locationLabels[label]; !exists {
			locationLabels[label] = loc
		} else {
			ctx.ModuleErrorf("multiple labels for %q, %q and %q",
				label, locationLabels[label], loc)
		}
	}

	var tools android.Paths
	var packagedTools []android.PackagingSpec
	if len(g.properties.Tools) > 0 {
		seenTools := make(map[string]bool)

		ctx.VisitDirectDepsBlueprint(func(module blueprint.Module) {
			switch tag := ctx.OtherModuleDependencyTag(module).(type) {
			case hostToolDependencyTag:
				tool := ctx.OtherModuleName(module)

				switch t := module.(type) {
				case android.HostToolProvider:
					// A HostToolProvider provides the path to a tool, which will be copied
					// into the sandbox.
					if !t.(android.Module).Enabled() {
						if ctx.Config().AllowMissingDependencies() {
							ctx.AddMissingDependencies([]string{tool})
						} else {
							ctx.ModuleErrorf("depends on disabled module %q", tool)
						}
						return
					}
					path := t.HostToolPath()
					if !path.Valid() {
						ctx.ModuleErrorf("host tool %q missing output file", tool)
						return
					}
					if specs := t.TransitivePackagingSpecs(); specs != nil {
						// If the HostToolProvider has PackgingSpecs, which are definitions of the
						// required relative locations of the tool and its dependencies, use those
						// instead.  They will be copied to those relative locations in the sbox
						// sandbox.
						packagedTools = append(packagedTools, specs...)
						// Assume that the first PackagingSpec of the module is the tool.
						addLocationLabel(tag.label, packagedToolLocation{specs[0]})
					} else {
						tools = append(tools, path.Path())
						addLocationLabel(tag.label, toolLocation{android.Paths{path.Path()}})
					}
				case bootstrap.GoBinaryTool:
					// A GoBinaryTool provides the install path to a tool, which will be copied.
					if s, err := filepath.Rel(android.PathForOutput(ctx).String(), t.InstallPath()); err == nil {
						toolPath := android.PathForOutput(ctx, s)
						tools = append(tools, toolPath)
						addLocationLabel(tag.label, toolLocation{android.Paths{toolPath}})
					} else {
						ctx.ModuleErrorf("cannot find path for %q: %v", tool, err)
						return
					}
				default:
					ctx.ModuleErrorf("%q is not a host tool provider", tool)
					return
				}

				seenTools[tag.label] = true
			}
		})

		// If AllowMissingDependencies is enabled, the build will not have stopped when
		// AddFarVariationDependencies was called on a missing tool, which will result in nonsensical
		// "cmd: unknown location label ..." errors later.  Add a placeholder file to the local label.
		// The command that uses this placeholder file will never be executed because the rule will be
		// replaced with an android.Error rule reporting the missing dependencies.
		if ctx.Config().AllowMissingDependencies() {
			for _, tool := range g.properties.Tools {
				if !seenTools[tool] {
					addLocationLabel(tool, errorLocation{"***missing tool " + tool + "***"})
				}
			}
		}
	}

	if ctx.Failed() {
		return
	}

	for _, toolFile := range g.properties.Tool_files {
		paths := android.PathsForModuleSrc(ctx, []string{toolFile})
		tools = append(tools, paths...)
		addLocationLabel(toolFile, toolLocation{paths})
	}

	if len(g.properties.Interfaces) != len(g.properties.Versions) {
		panic(fmt.Errorf("A version must be specified for each interface.  Interfaces: %s, Versions: %s", g.properties.Interfaces, g.properties.Versions))
	}

	versions := make([]float32, 0, len(g.properties.Versions))
	for _, s := range g.properties.Versions {
		v, err := strconv.ParseFloat(s, 32)
		versions = append(versions, float32(v))
		if err != nil {
			panic(fmt.Errorf("Cannot parse interface version %s as float", s))
		}
	}

	g.properties.Deps = append_unique(g.properties.Deps, g.properties.Fidl)
	g.properties.Deps = append_unique(g.properties.Deps, g.properties.Fdepl)
	var srcFiles android.Paths
	for _, in := range g.properties.Deps {
		paths, missingDeps := android.PathsAndMissingDepsForModuleSrcExcludes(ctx, []string{in}, g.properties.Exclude_srcs)
		if len(missingDeps) > 0 {
			if !ctx.Config().AllowMissingDependencies() {
				panic(fmt.Errorf("should never get here, the missing dependencies %q should have been reported in DepsMutator",
					missingDeps))
			}

			// If AllowMissingDependencies is enabled, the build will not have stopped when
			// the dependency was added on a missing SourceFileProducer module, which will result in nonsensical
			// "cmd: label ":..." has no files" errors later.  Add a placeholder file to the local label.
			// The command that uses this placeholder file will never be executed because the rule will be
			// replaced with an android.Error rule reporting the missing dependencies.
			ctx.AddMissingDependencies(missingDeps)
			addLocationLabel(in, errorLocation{"***missing dependencies " + in + "***"})
		} else {
			srcFiles = append(srcFiles, paths...)
			addLocationLabel(in, inputLocation{paths})
		}
	}

	fidlFile, missingDeps := android.PathsAndMissingDepsForModuleSrcExcludes(ctx, []string{g.properties.Fidl}, nil)
	if len(missingDeps) > 0 {
		panic(fmt.Errorf("Cannot find fidl: ", missingDeps))
	}

	fdeplFile, missingDeps := android.PathsAndMissingDepsForModuleSrcExcludes(ctx, []string{g.properties.Fdepl}, nil)
	if len(missingDeps) > 0 {
		panic(fmt.Errorf("Cannot find fdepl: ", missingDeps))
	}

	var copyFrom android.Paths
	var outputFiles android.WritablePaths
	var zipArgs strings.Builder

	g.properties.Generator_verbosity = input_or_default(g.properties.Generator_verbosity, "verbose")

	capi_cmd_fmt_parts := []string{}
	capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "$(location commonapi.generator.core)")
	capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "--loglevel={generator_verbosity}")
	capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "--dest-common=$(genDir)/{core_common}")
	if !g.properties.Disable_service_stub {
		capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "--dest-stub=$(genDir)/{core_stub}")
	}
	if !g.properties.Disable_proxy {
		capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "--dest-proxy=$(genDir)/{core_proxy}")
	}
	capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "--dest-skel=$(genDir)/{core_skeleton}")
	capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "-sk")
	capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "$(fdepl)")
	capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, ";")
	capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "$(location commonapi.generator.someip)")
	capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "--loglevel={generator_verbosity}")
	capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "--dest-common=$(genDir)/{someip_common}")

	if !g.properties.Disable_service_stub {
		capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "--dest-stub=$(genDir)/{someip_stub}")
	}
	if !g.properties.Disable_proxy {
		capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "--dest-proxy=$(genDir)/{someip_proxy}")
	}
	capi_cmd_fmt_parts = append(capi_cmd_fmt_parts, "$(fdepl)")

	capi_cmd_fmt := strings.Join(capi_cmd_fmt_parts, " ")
	capi_cmd_formatter := strings.NewReplacer(
		"{core_common}", g.Dest_dirs.Core_common,
		"{core_proxy}", g.Dest_dirs.Core_proxy,
		"{core_stub}", g.Dest_dirs.Core_stub,
		"{core_skeleton}", g.Dest_dirs.Core_skeleton,
		"{someip_common}", g.Dest_dirs.Someip_common,
		"{someip_proxy}", g.Dest_dirs.Someip_proxy,
		"{someip_stub}", g.Dest_dirs.Someip_stub,
		"{generator_verbosity}", g.properties.Generator_verbosity)
	capi_cmd := capi_cmd_formatter.Replace(capi_cmd_fmt)

	// Generate tasks, either from genrule or gensrcs.
	for _, task := range g.taskGenerator(ctx, capi_cmd, g.Dest_dirs, g.properties.Interfaces, versions, srcFiles, g.properties.Additional_out, g.properties.Disable_service_stub, g.properties.Disable_proxy) {
		if len(task.out) == 0 {
			ctx.ModuleErrorf("must have at least one output file")
			return
		}

		// Pick a unique path outside the task.genDir for the sbox manifest textproto,
		// a unique rule name, and the user-visible description.
		manifestName := "genrule.sbox.textproto"
		desc := "generate"
		name := "generator"
		if task.shards > 0 {
			manifestName = "genrule_" + strconv.Itoa(task.shard) + ".sbox.textproto"
			desc += " " + strconv.Itoa(task.shard)
			name += strconv.Itoa(task.shard)
		} else if len(task.out) == 1 {
			desc += " " + task.out[0].Base()
		}

		manifestPath := android.PathForModuleOut(ctx, manifestName)

		// Use a RuleBuilder to create a rule that runs the command inside an sbox sandbox.
		rule := android.NewRuleBuilder(pctx, ctx).Sbox(task.genDir, manifestPath).SandboxTools()
		cmd := rule.Command()

		for _, out := range task.out {
			addLocationLabel(out.Rel(), outputLocation{out})
		}

		referencedDepfile := false

		rawCommand, err := android.Expand(task.cmd, func(name string) (string, error) {
			// report the error directly without returning an error to android.Expand to catch multiple errors in a
			// single run
			reportError := func(fmt string, args ...interface{}) (string, error) {
				ctx.PropertyErrorf("cmd", fmt, args...)
				return "SOONG_ERROR", nil
			}

			switch name {
			case "location":
				if len(g.properties.Tools) == 0 && len(g.properties.Tool_files) == 0 {
					return reportError("at least one `tools` or `tool_files` is required if $(location) is used")
				}
				loc := locationLabels[firstLabel]
				paths := loc.Paths(cmd)
				if len(paths) == 0 {
					return reportError("default label %q has no files", firstLabel)
				} else if len(paths) > 1 {
					return reportError("default label %q has multiple files, use $(locations %s) to reference it",
						firstLabel, firstLabel)
				}
				return paths[0], nil
			case "fidl":
				return strings.Join(cmd.PathsForInputs(fidlFile), " "), nil
			case "fdepl":
				return strings.Join(cmd.PathsForInputs(fdeplFile), " "), nil
			case "in":
				return strings.Join(cmd.PathsForInputs(srcFiles), " "), nil
			case "out":
				var sandboxOuts []string
				for _, out := range task.out {
					sandboxOuts = append(sandboxOuts, cmd.PathForOutput(out))
				}
				return strings.Join(sandboxOuts, " "), nil
			case "depfile":
				referencedDepfile = true
				if !Bool(g.properties.Depfile) {
					return reportError("$(depfile) used without depfile property")
				}
				return "__SBOX_DEPFILE__", nil
			case "genDir":
				return cmd.PathForOutput(task.genDir), nil
			case "coreSkeleton":
				return g.Dest_dirs.Core_skeleton, nil
			case "coreCommon":
				return g.Dest_dirs.Core_common, nil
			case "coreProxy":
				return g.Dest_dirs.Core_proxy, nil
			case "coreStub":
				return g.Dest_dirs.Core_stub, nil
			case "someipCommon":
				return g.Dest_dirs.Someip_common, nil
			case "someipProxy":
				return g.Dest_dirs.Someip_proxy, nil
			case "someipStub":
				return g.Dest_dirs.Someip_stub, nil

			default:
				if strings.HasPrefix(name, "location ") {
					label := strings.TrimSpace(strings.TrimPrefix(name, "location "))
					if loc, ok := locationLabels[label]; ok {
						paths := loc.Paths(cmd)
						if len(paths) == 0 {
							return reportError("label %q has no files", label)
						} else if len(paths) > 1 {
							return reportError("label %q has multiple files, use $(locations %s) to reference it",
								label, label)
						}
						return paths[0], nil
					} else {
						return reportError("unknown location label %q", label)
					}
				} else if strings.HasPrefix(name, "locations ") {
					label := strings.TrimSpace(strings.TrimPrefix(name, "locations "))
					if loc, ok := locationLabels[label]; ok {
						paths := loc.Paths(cmd)
						if len(paths) == 0 {
							return reportError("label %q has no files", label)
						}
						return strings.Join(paths, " "), nil
					} else {
						return reportError("unknown locations label %q", label)
					}
				} else {
					return reportError("unknown variable '$(%s)'", name)
				}
			}
		})

		if err != nil {
			ctx.PropertyErrorf("cmd", "%s", err.Error())
			return
		}

		if Bool(g.properties.Depfile) && !referencedDepfile {
			ctx.PropertyErrorf("cmd", "specified depfile=true but did not include a reference to '${depfile}' in cmd")
			return
		}
		g.rawCommands = append(g.rawCommands, rawCommand)

		cmd.Text(rawCommand)
		cmd.ImplicitOutputs(task.out)
		cmd.Implicits(task.in)
		cmd.ImplicitTools(tools)
		cmd.ImplicitTools(task.extraTools)
		cmd.ImplicitPackagedTools(packagedTools)
		if Bool(g.properties.Depfile) {
			cmd.ImplicitDepFile(task.depFile)
		}

		// Create the rule to run the genrule command inside sbox.
		rule.Build(name, desc)

		if len(task.copyTo) > 0 {
			// If copyTo is set, multiple shards need to be copied into a single directory.
			// task.out contains the per-shard paths, and copyTo contains the corresponding
			// final path.  The files need to be copied into the final directory by a
			// single rule so it can remove the directory before it starts to ensure no
			// old files remain.  zipsync already does this, so build up zipArgs that
			// zip all the per-shard directories into a single zip.
			outputFiles = append(outputFiles, task.copyTo...)
			copyFrom = append(copyFrom, task.out.Paths()...)
			zipArgs.WriteString(" -C " + task.genDir.String())
			zipArgs.WriteString(android.JoinWithPrefix(task.out.Strings(), " -f "))
		} else {
			outputFiles = append(outputFiles, task.out...)
		}
	}

	if len(copyFrom) > 0 {
		// Create a rule that zips all the per-shard directories into a single zip and then
		// uses zipsync to unzip it into the final directory.
		ctx.Build(pctx, android.BuildParams{
			Rule:        gensrcsMerge,
			Implicits:   copyFrom,
			Outputs:     outputFiles,
			Description: "merge shards",
			Args: map[string]string{
				"zipArgs": zipArgs.String(),
				"tmpZip":  android.PathForModuleGen(ctx, g.subDir+".zip").String(),
				"genDir":  android.PathForModuleGen(ctx, g.subDir).String(),
			},
		})
	}

	g.outputFiles = outputFiles.Paths()

	// For <= 6 outputs, just embed those directly in the users. Right now, that covers >90% of
	// the genrules on AOSP. That will make things simpler to look at the graph in the common
	// case. For larger sets of outputs, inject a phony target in between to limit ninja file
	// growth.
	if len(g.outputFiles) <= 6 {
		g.outputDeps = g.outputFiles
	} else {
		phonyFile := android.PathForModuleGen(ctx, "genrule-phony")
		ctx.Build(pctx, android.BuildParams{
			Rule:   blueprint.Phony,
			Output: phonyFile,
			Inputs: g.outputFiles,
		})
		g.outputDeps = android.Paths{phonyFile}
	}
}

func (g *Module) AndroidMk() android.AndroidMkData {
	return android.AndroidMkData{
		Class:      "ETC",
		OutputFile: android.OptionalPathForPath(g.outputFiles[0]),
		SubName:    g.subName,
		Extra: []android.AndroidMkExtraFunc{
			func(w io.Writer, outputFile android.Path) {
				fmt.Fprintln(w, "LOCAL_UNINSTALLABLE_MODULE := true")
			},
		},
		Custom: func(w io.Writer, name, prefix, moduleDir string, data android.AndroidMkData) {
			android.WriteAndroidMkData(w, data)
			if data.SubName != "" {
				fmt.Fprintln(w, ".PHONY:", name)
				fmt.Fprintln(w, name, ":", name+g.subName)
			}
		},
	}
}

var _ android.ApexModule = (*Module)(nil)

// Implements android.ApexModule
func (g *Module) ShouldSupportSdkVersion(ctx android.BaseModuleContext,
	sdkVersion android.ApiLevel) error {
	// Because generated outputs are checked by client modules(e.g. cc_library, ...)
	// we can safely ignore the check here.
	return nil
}

func generatorFactory(taskGenerator taskFunc, props ...interface{}) *Module {
	module := &Module{
		taskGenerator: taskGenerator,
	}

	module.AddProperties(props...)
	module.AddProperties(&module.properties)

	module.ImageInterface = noopImageInterface{}

	return module
}

type noopImageInterface struct{}

func (x noopImageInterface) ImageMutatorBegin(android.BaseModuleContext)                 {}
func (x noopImageInterface) CoreVariantNeeded(android.BaseModuleContext) bool            { return false }
func (x noopImageInterface) RamdiskVariantNeeded(android.BaseModuleContext) bool         { return false }
func (x noopImageInterface) VendorRamdiskVariantNeeded(android.BaseModuleContext) bool   { return false }
func (x noopImageInterface) DebugRamdiskVariantNeeded(android.BaseModuleContext) bool    { return false }
func (x noopImageInterface) RecoveryVariantNeeded(android.BaseModuleContext) bool        { return false }
func (x noopImageInterface) ExtraImageVariations(ctx android.BaseModuleContext) []string { return nil }
func (x noopImageInterface) SetImageVariation(ctx android.BaseModuleContext, variation string, module android.Module) {
}

type genSrcsProperties struct {
	// extension that will be substituted for each output file
	Output_extension *string

	// maximum number of files that will be passed on a single command line.
	Shard_size *int64
}

const defaultShardSize = 50

func NewGenRule() *Module {
	properties := &genRuleProperties{}

	taskGenerator := func(ctx android.ModuleContext, rawCommand string, dest_dirs capiDestDirs, interfaces []string, versions []float32, srcFiles android.Paths, outFiles []string, disable_stub bool, disable_proxy bool) []generateTask {

		// Determine the outputs specified by the interface
		split_interface := func(name string) (string, string) {
			parts := strings.Split(name, ".")
			basename := parts[len(parts)-1]
			namespace := strings.Join(parts[0:len(parts)-1], "/")
			return namespace, basename
		}

		gen_path := func(ctx android.ModuleContext, dest string, version string, interface_dir string, interface_basename string, suffix string) android.WritablePath {
			v := android.PathForModuleGen(ctx, dest, version, interface_dir, interface_basename+suffix)
			return v
		}

		var core_headers android.WritablePaths
		var middleware_headers android.WritablePaths
		var middleware_impls android.WritablePaths
		for i, cint := range interfaces {
			dir, basename := split_interface(cint)

			var version_str string
			if versions[i] > 0 {
				version_str = fmt.Sprintf("v%1.0f", versions[i])
			}

			if !disable_stub {
				core_headers = append(core_headers, gen_path(ctx, dest_dirs.Core_skeleton, version_str, dir, basename, "StubDefault.hpp"))
				core_headers = append(core_headers, gen_path(ctx, dest_dirs.Core_stub, version_str, dir, basename, "Stub.hpp"))
				middleware_headers = append(middleware_headers, gen_path(ctx, dest_dirs.Someip_stub, version_str, dir, basename, "SomeIPStubAdapter.hpp"))
				middleware_impls = append(middleware_impls, gen_path(ctx, dest_dirs.Someip_stub, version_str, dir, basename, "SomeIPStubAdapter.cpp"))
			}

			if !disable_proxy {
				core_headers = append(core_headers, gen_path(ctx, dest_dirs.Core_proxy, version_str, dir, basename, "Proxy.hpp"))
				core_headers = append(core_headers, gen_path(ctx, dest_dirs.Core_proxy, version_str, dir, basename, "ProxyBase.hpp"))
				middleware_headers = append(middleware_headers, gen_path(ctx, dest_dirs.Someip_proxy, version_str, dir, basename, "SomeIPProxy.hpp"))
				middleware_impls = append(middleware_impls, gen_path(ctx, dest_dirs.Someip_proxy, version_str, dir, basename, "SomeIPProxy.cpp"))
			}

			core_headers = append(core_headers, gen_path(ctx, dest_dirs.Core_common, version_str, dir, basename, ".hpp"))
			middleware_headers = append(middleware_headers, gen_path(ctx, dest_dirs.Someip_common, version_str, dir, basename, "SomeIPDeployment.hpp"))

		}
		additional_outfiles := make(android.WritablePaths, 0, len(outFiles))
		for _, ao := range outFiles {
			additional_outfiles = append(additional_outfiles, android.PathForModuleGen(ctx, ao))
		}

		user_outs := make(android.WritablePaths, len(properties.Out))
		var depFile android.WritablePath
		for i, out := range properties.Out {
			outPath := android.PathForModuleGen(ctx, out)
			if i == 0 {
				depFile = outPath.ReplaceExtension(ctx, "d")
			}
			user_outs[i] = outPath
		}

		outs := make(android.WritablePaths, 0, len(user_outs)+len(core_headers)+len(middleware_headers)+len(middleware_impls)+len(additional_outfiles))
		outs = append(outs, user_outs...)
		outs = append(outs, core_headers...)
		outs = append(outs, middleware_headers...)
		outs = append(outs, middleware_impls...)
		outs = append(outs, additional_outfiles...)

		return []generateTask{{
			in:      srcFiles,
			out:     outs,
			depFile: depFile,
			genDir:  android.PathForModuleGen(ctx),
			cmd:     rawCommand,
		}}
	}

	return generatorFactory(taskGenerator, properties)
}

func capiCodeGenModuleFactory() android.Module {
	m := NewGenRule()
	android.InitAndroidModule(m)
	return m
}

type genRuleProperties struct {
	// names of the output files that will be generated
	Out []string `android:"arch_variant"`
}

var Bool = proptools.Bool
var String = proptools.String

// Defaults
type Defaults struct {
	android.ModuleBase
	android.DefaultsModuleBase
}
