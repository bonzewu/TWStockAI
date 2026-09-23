#!/usr/bin/env python3
"""
產生 TWStockAI.xcodeproj（Xcode 15 / objectVersion 56）。

用途：本專案的 .xcodeproj 由本腳本產生，新增或刪除 Swift 檔案後重新執行即可，
      不需手動維護 project.pbxproj。

用法：python3 tools/generate_xcodeproj.py
"""
import os
import hashlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = "TWStockAI"
UNIT_TESTS = "TWStockAITests"
UI_TESTS = "TWStockAIUITests"
BUNDLE_ID = "com.bonzewu.TWStockAI"
DEPLOYMENT_TARGET = "13.0"

_counter = [0]


def uid(seed: str) -> str:
    """產生穩定且唯一的 24 位十六進位識別碼。"""
    _counter[0] += 1
    return hashlib.md5(f"{seed}-{_counter[0]}".encode()).hexdigest().upper()[:24]


def scan_sources(folder: str) -> dict:
    """掃描資料夾內的 Swift 檔案，回傳 {相對路徑: [檔名]}。"""
    result = {}
    base = os.path.join(ROOT, folder)
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames.sort()
        swift = sorted(f for f in filenames if f.endswith(".swift"))
        if swift:
            result[os.path.relpath(dirpath, base)] = swift
    return result


class ProjectBuilder:
    """以逐段累積的方式組出 project.pbxproj 內容。"""

    def __init__(self):
        self.build_files = []
        self.file_refs = []
        self.groups = []
        self.file_ids = {}

    # ---- 檔案與群組 ----

    def add_source(self, folder, rel, name):
        """登記一個 Swift 來源檔，回傳 (fileRef, buildFile)。"""
        key = (folder, rel, name)
        fref, bfile = uid(f"fref-{key}"), uid(f"bfile-{key}")
        self.file_ids[key] = (fref, bfile)
        self.file_refs.append(
            f'\t\t{fref} /* {name} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.swift; path = "{name}"; sourceTree = "<group>"; }};'
        )
        self.build_files.append(
            f'\t\t{bfile} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fref} /* {name} */; }};'
        )
        return fref, bfile

    def add_file_ref(self, name, file_type, path=None, source_tree='"<group>"'):
        """登記一個非來源檔的參考（資源、entitlements、產出物）。"""
        fref = uid(f"ref-{name}")
        self.file_refs.append(
            f'\t\t{fref} /* {name} */ = {{isa = PBXFileReference; {file_type} '
            f'path = "{path or name}"; sourceTree = {source_tree}; }};'
        )
        return fref

    def add_group(self, name, children, path=None, group_name=None):
        """登記一個群組，children 為已格式化的子項目字串陣列。"""
        gid = uid(f"group-{name}-{path}")
        attributes = ""
        if group_name:
            attributes += f'name = "{group_name}"; '
        if path:
            attributes += f'path = "{path}"; '
        body = "\n".join(f"\t\t\t\t{child}," for child in children)
        self.groups.append(
            f'\t\t{gid} /* {name} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n'
            f'{body}\n\t\t\t);\n\t\t\t{attributes}sourceTree = "<group>";\n\t\t}};'
        )
        return gid

    def build_tree(self, folder, sources, extra_root_children=None, root_name=None):
        """依資料夾階層建立群組樹，回傳根群組 ID。"""
        tree = {}
        for rel in sources:
            node = tree
            if rel != ".":
                for part in rel.split(os.sep):
                    node = node.setdefault(part, {})

        def walk(rel, node, name):
            children = []
            for sub in sorted(node):
                sub_rel = sub if rel == "." else os.path.join(rel, sub)
                children.append(f"{walk(sub_rel, node[sub], sub)} /* {sub} */")
            for f in sources.get(rel, []):
                children.append(f"{self.file_ids[(folder, rel, f)][0]} /* {f} */")
            if rel == "." and extra_root_children:
                children.extend(extra_root_children)
            if rel == ".":
                return self.add_group(name, children, path=folder, group_name=root_name or folder)
            return self.add_group(name, children, path=name)

        return walk(".", tree, folder)


def generate():
    builder = ProjectBuilder()

    # ---- 掃描三個 target 的來源檔 ----
    app_sources = scan_sources(APP)
    unit_sources = scan_sources(UNIT_TESTS)
    ui_sources = scan_sources(UI_TESTS)

    phase_files = {APP: [], UNIT_TESTS: [], UI_TESTS: []}
    for folder, sources in ((APP, app_sources), (UNIT_TESTS, unit_sources), (UI_TESTS, ui_sources)):
        for rel, files in sorted(sources.items()):
            for name in files:
                _, bfile = builder.add_source(folder, rel, name)
                phase_files[folder].append(f"\t\t\t\t{bfile} /* {name} in Sources */,")

    # ---- 資源與設定檔 ----
    assets_ref = builder.add_file_ref("Assets.xcassets", "lastKnownFileType = folder.assetcatalog;")
    assets_build = uid("assets-build")
    builder.build_files.append(
        f'\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; '
        f'fileRef = {assets_ref} /* Assets.xcassets */; }};'
    )
    entitlements_ref = builder.add_file_ref(f"{APP}.entitlements", "lastKnownFileType = text.plist.entitlements;")

    # ---- 產出物 ----
    app_product = builder.add_file_ref(
        f"{APP}.app", "explicitFileType = wrapper.application; includeInIndex = 0;",
        source_tree="BUILT_PRODUCTS_DIR")
    unit_product = builder.add_file_ref(
        f"{UNIT_TESTS}.xctest", "explicitFileType = wrapper.cfbundle; includeInIndex = 0;",
        source_tree="BUILT_PRODUCTS_DIR")
    ui_product = builder.add_file_ref(
        f"{UI_TESTS}.xctest", "explicitFileType = wrapper.cfbundle; includeInIndex = 0;",
        source_tree="BUILT_PRODUCTS_DIR")

    # ---- 群組樹 ----
    app_group = builder.build_tree(
        APP, app_sources,
        extra_root_children=[f"{assets_ref} /* Assets.xcassets */",
                             f"{entitlements_ref} /* {APP}.entitlements */"])
    unit_group = builder.build_tree(UNIT_TESTS, unit_sources)
    ui_group = builder.build_tree(UI_TESTS, ui_sources)
    tools_group = builder.add_group("tools", [], path="tools") if False else None

    products_group = builder.add_group("Products", [
        f"{app_product} /* {APP}.app */",
        f"{unit_product} /* {UNIT_TESTS}.xctest */",
        f"{ui_product} /* {UI_TESTS}.xctest */",
    ], group_name="Products")

    main_group = builder.add_group("MainGroup", [
        f"{app_group} /* {APP} */",
        f"{unit_group} /* {UNIT_TESTS} */",
        f"{ui_group} /* {UI_TESTS} */",
        f"{products_group} /* Products */",
    ])

    # ---- 識別碼 ----
    ids = {name: uid(name) for name in [
        "project", "app-target", "unit-target", "ui-target",
        "app-sources", "app-frameworks", "app-resources",
        "unit-sources", "unit-frameworks", "unit-resources",
        "ui-sources", "ui-frameworks", "ui-resources",
        "proj-cfg", "app-cfg", "unit-cfg", "ui-cfg",
        "proj-debug", "proj-release", "app-debug", "app-release",
        "unit-debug", "unit-release", "ui-debug", "ui-release",
        "unit-dep", "ui-dep", "unit-proxy", "ui-proxy",
    ]}

    project_common = f"""				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				MACOSX_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};
				SDKROOT = macosx;
				SWIFT_VERSION = 5.0;"""

    app_common = f"""				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "{APP}/{APP}.entitlements";
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "台股 AI 分析";
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.finance";
				INFOPLIST_KEY_NSPrincipalClass = NSApplication;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "{BUNDLE_ID}";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;"""

    unit_common = f"""				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "{BUNDLE_ID}Tests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/{APP}.app/Contents/MacOS/{APP}";"""

    ui_common = f"""				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "{BUNDLE_ID}UITests";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				TEST_TARGET_NAME = "{APP}";"""

    def phase(pid, kind, files, label):
        body = "\n".join(files)
        return (f'\t\t{pid} /* {label} */ = {{\n\t\t\tisa = {kind};\n'
                f'\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n{body}\n\t\t\t);\n'
                f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};')

    sources_phases = "\n".join([
        phase(ids["app-sources"], "PBXSourcesBuildPhase", phase_files[APP], "Sources"),
        phase(ids["unit-sources"], "PBXSourcesBuildPhase", phase_files[UNIT_TESTS], "Sources"),
        phase(ids["ui-sources"], "PBXSourcesBuildPhase", phase_files[UI_TESTS], "Sources"),
    ])
    frameworks_phases = "\n".join([
        phase(ids[key], "PBXFrameworksBuildPhase", [], "Frameworks")
        for key in ("app-frameworks", "unit-frameworks", "ui-frameworks")
    ])
    resources_phases = "\n".join([
        phase(ids["app-resources"], "PBXResourcesBuildPhase",
              [f"\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,"], "Resources"),
        phase(ids["unit-resources"], "PBXResourcesBuildPhase", [], "Resources"),
        phase(ids["ui-resources"], "PBXResourcesBuildPhase", [], "Resources"),
    ])

    def native_target(tid, name, cfg, phases, product, product_type, dependencies=""):
        phase_list = "\n".join(f"\t\t\t\t{p} /* {label} */," for p, label in phases)
        return f"""		{tid} /* {name} */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {cfg} /* Build configuration list for PBXNativeTarget "{name}" */;
			buildPhases = (
{phase_list}
			);
			buildRules = (
			);
			dependencies = (
{dependencies}
			);
			name = "{name}";
			productName = "{name}";
			productReference = {product} /* {name} */;
			productType = "{product_type}";
		}};"""

    targets = "\n".join([
        native_target(ids["app-target"], APP, ids["app-cfg"],
                      [(ids["app-sources"], "Sources"), (ids["app-frameworks"], "Frameworks"),
                       (ids["app-resources"], "Resources")],
                      app_product, "com.apple.product-type.application"),
        native_target(ids["unit-target"], UNIT_TESTS, ids["unit-cfg"],
                      [(ids["unit-sources"], "Sources"), (ids["unit-frameworks"], "Frameworks"),
                       (ids["unit-resources"], "Resources")],
                      unit_product, "com.apple.product-type.bundle.unit-test",
                      dependencies=f'\t\t\t\t{ids["unit-dep"]} /* PBXTargetDependency */,'),
        native_target(ids["ui-target"], UI_TESTS, ids["ui-cfg"],
                      [(ids["ui-sources"], "Sources"), (ids["ui-frameworks"], "Frameworks"),
                       (ids["ui-resources"], "Resources")],
                      ui_product, "com.apple.product-type.bundle.ui-testing",
                      dependencies=f'\t\t\t\t{ids["ui-dep"]} /* PBXTargetDependency */,'),
    ])

    def build_config(cid, name, settings):
        return (f'\t\t{cid} /* {name} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n'
                f'\t\t\tbuildSettings = {{\n{settings}\n\t\t\t}};\n\t\t\tname = {name};\n\t\t}};')

    debug_extra = """				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";"""
    release_extra = """				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				MTL_ENABLE_DEBUG_INFO = NO;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";"""

    configurations = "\n".join([
        build_config(ids["proj-debug"], "Debug", project_common + "\n" + debug_extra),
        build_config(ids["proj-release"], "Release", project_common + "\n" + release_extra),
        build_config(ids["app-debug"], "Debug", app_common),
        build_config(ids["app-release"], "Release", app_common),
        build_config(ids["unit-debug"], "Debug", unit_common),
        build_config(ids["unit-release"], "Release", unit_common),
        build_config(ids["ui-debug"], "Debug", ui_common),
        build_config(ids["ui-release"], "Release", ui_common),
    ])

    def config_list(cid, debug, release, label):
        return f"""		{cid} /* Build configuration list for {label} */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug} /* Debug */,
				{release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};"""

    config_lists = "\n".join([
        config_list(ids["proj-cfg"], ids["proj-debug"], ids["proj-release"], f'PBXProject "{APP}"'),
        config_list(ids["app-cfg"], ids["app-debug"], ids["app-release"], f'PBXNativeTarget "{APP}"'),
        config_list(ids["unit-cfg"], ids["unit-debug"], ids["unit-release"], f'PBXNativeTarget "{UNIT_TESTS}"'),
        config_list(ids["ui-cfg"], ids["ui-debug"], ids["ui-release"], f'PBXNativeTarget "{UI_TESTS}"'),
    ])

    dependencies = f"""		{ids["unit-dep"]} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {ids["app-target"]} /* {APP} */;
			targetProxy = {ids["unit-proxy"]} /* PBXContainerItemProxy */;
		}};
		{ids["ui-dep"]} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {ids["app-target"]} /* {APP} */;
			targetProxy = {ids["ui-proxy"]} /* PBXContainerItemProxy */;
		}};"""

    proxies = f"""		{ids["unit-proxy"]} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {ids["project"]} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {ids["app-target"]};
			remoteInfo = "{APP}";
		}};
		{ids["ui-proxy"]} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {ids["project"]} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {ids["app-target"]};
			remoteInfo = "{APP}";
		}};"""

    content = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(builder.build_files)}
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
{proxies}
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
{chr(10).join(builder.file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
{frameworks_phases}
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{chr(10).join(builder.groups)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
{targets}
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{ids["project"]} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {{
					{ids["app-target"]} = {{
						CreatedOnToolsVersion = 15.0;
					}};
					{ids["unit-target"]} = {{
						CreatedOnToolsVersion = 15.0;
						TestTargetID = {ids["app-target"]};
					}};
					{ids["ui-target"]} = {{
						CreatedOnToolsVersion = 15.0;
						TestTargetID = {ids["app-target"]};
					}};
				}};
			}};
			buildConfigurationList = {ids["proj-cfg"]} /* Build configuration list for PBXProject "{APP}" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = "zh-Hant";
			hasScannedForEncodings = 0;
			knownRegions = (
				"zh-Hant",
				Base,
			);
			mainGroup = {main_group};
			productRefGroup = {products_group} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{ids["app-target"]} /* {APP} */,
				{ids["unit-target"]} /* {UNIT_TESTS} */,
				{ids["ui-target"]} /* {UI_TESTS} */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{resources_phases}
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{sources_phases}
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
{dependencies}
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
{configurations}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
{config_lists}
/* End XCConfigurationList section */
	}};
	rootObject = {ids["project"]} /* Project object */;
}}
"""

    project_dir = os.path.join(ROOT, f"{APP}.xcodeproj")
    os.makedirs(project_dir, exist_ok=True)
    with open(os.path.join(project_dir, "project.pbxproj"), "w", encoding="utf-8") as handle:
        handle.write(content)

    write_scheme(project_dir, ids)

    total = sum(len(v) for v in app_sources.values())
    tests = sum(len(v) for v in unit_sources.values()) + sum(len(v) for v in ui_sources.values())
    print(f"已產生 {APP}.xcodeproj：App 來源 {total} 檔、測試來源 {tests} 檔。")


def write_scheme(project_dir: str, ids: dict):
    """寫出共用 scheme，讓 Xcode 開啟後即可直接執行與測試。"""
    scheme_dir = os.path.join(project_dir, "xcshareddata", "xcschemes")
    os.makedirs(scheme_dir, exist_ok=True)

    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['app-target']}"
               BuildableName = "{APP}.app"
               BlueprintName = "{APP}"
               ReferencedContainer = "container:{APP}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['unit-target']}"
               BuildableName = "{UNIT_TESTS}.xctest"
               BlueprintName = "{UNIT_TESTS}"
               ReferencedContainer = "container:{APP}.xcodeproj">
            </BuildableReference>
         </TestableReference>
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{ids['ui-target']}"
               BuildableName = "{UI_TESTS}.xctest"
               BlueprintName = "{UI_TESTS}"
               ReferencedContainer = "container:{APP}.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{ids['app-target']}"
            BuildableName = "{APP}.app"
            BlueprintName = "{APP}"
            ReferencedContainer = "container:{APP}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{ids['app-target']}"
            BuildableName = "{APP}.app"
            BlueprintName = "{APP}"
            ReferencedContainer = "container:{APP}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    with open(os.path.join(scheme_dir, f"{APP}.xcscheme"), "w", encoding="utf-8") as handle:
        handle.write(scheme)


if __name__ == "__main__":
    generate()
