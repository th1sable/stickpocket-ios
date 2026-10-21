#!/usr/bin/env python3
"""Regenerate the Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
app = root / "StickPocket"
objects = {}


def ident(label):
    return hashlib.sha1(label.encode()).hexdigest()[:24].upper()


def add(key, isa, **values):
    oid = ident(key)
    objects[oid] = {"isa": isa, **values}
    return oid


sources = sorted(app.rglob("*.swift"))
tests = sorted((root / "Tests").glob("*.swift"))
assets = app / "Assets.xcassets"
fixture = root / "Tests/Fixtures/animated.gif"
resources = [app / "Web/VisibleImages.js", assets, app / "PrivacyInfo.xcprivacy"]
appfiles = sources + resources + [app / "Info.plist"]
testfiles = tests + [fixture]


def fileref(path):
    rel = str(path.relative_to(root))
    kinds = {
        ".swift": "sourcecode.swift", ".js": "sourcecode.javascript",
        ".xcassets": "folder.assetcatalog", ".xcprivacy": "text.xml",
        ".plist": "text.plist.xml", ".gif": "image.gif"
    }
    return add("file:" + rel, "PBXFileReference", lastKnownFileType=kinds[path.suffix],
               path=rel, sourceTree="<group>")


refs = {p: fileref(p) for p in appfiles + testfiles}


def phase(key, kind, files):
    build = [add("build:" + key + str(p.relative_to(root)), "PBXBuildFile", fileRef=refs[p]) for p in files]
    return add(key, kind, buildActionMask=2147483647, files=build, runOnlyForDeploymentPostprocessing=0)


app_phases = [
    phase("app-sources", "PBXSourcesBuildPhase", sources),
    phase("app-frameworks", "PBXFrameworksBuildPhase", []),
    phase("app-resources", "PBXResourcesBuildPhase", resources)
]
test_phases = [
    phase("test-sources", "PBXSourcesBuildPhase", tests),
    phase("test-frameworks", "PBXFrameworksBuildPhase", []),
    phase("test-resources", "PBXResourcesBuildPhase", [fixture])
]
app_product = add("app-product", "PBXFileReference", explicitFileType="wrapper.application",
                  includeInIndex=0, path="StickPocket.app", sourceTree="BUILT_PRODUCTS_DIR")
test_product = add("test-product", "PBXFileReference", explicitFileType="wrapper.cfbundle",
                   includeInIndex=0, path="StickPocketTests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
products = add("products", "PBXGroup", children=[app_product, test_product], name="Products", sourceTree="<group>")
app_group = add("app-group", "PBXGroup", children=[refs[p] for p in appfiles], name="StickPocket", sourceTree="<group>")
test_group = add("test-group", "PBXGroup", children=[refs[p] for p in testfiles], name="Tests", sourceTree="<group>")
main = add("main-group", "PBXGroup", children=[app_group, test_group, products], sourceTree="<group>")


def config_list(key, base):
    ids = []
    for variant in ["Debug", "Release"]:
        settings = dict(base)
        settings.update({
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if variant == "Debug" else "-O",
            "DEBUG_INFORMATION_FORMAT": "dwarf" if variant == "Debug" else "dwarf-with-dsym"
        })
        if variant == "Debug":
            settings.update({"ENABLE_TESTABILITY": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
                             "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"]})
        else:
            settings["SWIFT_COMPILATION_MODE"] = "wholemodule"
        ids.append(add(key + variant, "XCBuildConfiguration", buildSettings=settings, name=variant))
    return add(key + "-list", "XCConfigurationList", buildConfigurations=ids,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Release")


common = {
    "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "SDKROOT": "iphoneos",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SWIFT_VERSION": "5.0",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES"
}
project_configs = config_list("project-config", common)
app_configs = config_list("app-config", {
    "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.luigi.stickpocket",
    "INFOPLIST_FILE": "StickPocket/Info.plist", "GENERATE_INFOPLIST_FILE": "NO",
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "TARGETED_DEVICE_FAMILY": "1",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
    "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO", "CODE_SIGN_STYLE": "Automatic",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"]
})
test_configs = config_list("test-config", {
    "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.luigi.stickpocket.tests",
    "GENERATE_INFOPLIST_FILE": "YES", "TARGETED_DEVICE_FAMILY": "1",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "CODE_SIGN_STYLE": "Automatic",
    "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/StickPocket.app/StickPocket", "BUNDLE_LOADER": "$(TEST_HOST)",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"]
})
app_target = add("app-target", "PBXNativeTarget", buildConfigurationList=app_configs,
                 buildPhases=app_phases, buildRules=[], dependencies=[], name="StickPocket",
                 productName="StickPocket", productReference=app_product,
                 productType="com.apple.product-type.application")
proxy = add("test-proxy", "PBXContainerItemProxy", containerPortal=ident("project"),
            proxyType=1, remoteGlobalIDString=app_target, remoteInfo="StickPocket")
dependency = add("test-dep", "PBXTargetDependency", target=app_target, targetProxy=proxy)
test_target = add("test-target", "PBXNativeTarget", buildConfigurationList=test_configs,
                  buildPhases=test_phases, buildRules=[], dependencies=[dependency], name="StickPocketTests",
                  productName="StickPocketTests", productReference=test_product,
                  productType="com.apple.product-type.bundle.unit-test")
project_id = add("project", "PBXProject", attributes={
    "BuildIndependentTargetsInParallel": "YES", "LastUpgradeCheck": "1600",
    "TargetAttributes": {
        app_target: {"CreatedOnToolsVersion": "16.0"},
        test_target: {"CreatedOnToolsVersion": "16.0", "TestTargetID": app_target}
    }
}, buildConfigurationList=project_configs, compatibilityVersion="Xcode 14.0",
    developmentRegion="it", hasScannedForEncodings=0, knownRegions=["it", "en", "Base"],
    mainGroup=main, productRefGroup=products, projectDirPath="", projectRoot="",
    targets=[app_target, test_target])


def oldplist(value, level=0):
    indent = "\t" * level
    if isinstance(value, dict):
        return "{\n" + "".join(indent + "\t" + oldplist(k) + " = " + oldplist(v, level + 1) + ";\n"
                               for k, v in value.items()) + indent + "}"
    if isinstance(value, list):
        return "(\n" + "".join(indent + "\t" + oldplist(v, level + 1) + ",\n" for v in value) + indent + ")"
    if isinstance(value, int):
        return str(value)
    return str(value) if re.fullmatch(r"[A-Za-z0-9_./]+", str(value)) else json.dumps(str(value), ensure_ascii=False)


project = {"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": objects, "rootObject": project_id}
xcode = root / "StickPocket.xcodeproj"
xcode.mkdir(exist_ok=True)
(xcode / "project.pbxproj").write_text("// !$*UTF8*$!\n" + oldplist(project) + "\n")
workspace = xcode / "project.xcworkspace"
workspace.mkdir(exist_ok=True)
(workspace / "contents.xcworkspacedata").write_text(
    '<?xml version="1.0" encoding="UTF-8"?><Workspace version="1.0"><FileRef location="self:"/></Workspace>')
schemes = xcode / "xcshareddata/xcschemes"
schemes.mkdir(parents=True, exist_ok=True)


def buildable(target, name):
    return (f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" '
            f'BuildableName="{name}" BlueprintName="{name.split(".")[0]}" '
            'ReferencedContainer="container:StickPocket.xcodeproj"/>')


appref = buildable(app_target, "StickPocket.app")
testref = buildable(test_target, "StickPocketTests.xctest")
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{appref}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{testref}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{testref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(schemes / "StickPocket.xcscheme").write_text(scheme)
(root / "scripts/project-structure.json").write_text(json.dumps(project, indent=2))
print(f"Xcode: {len(sources)} file Swift app, {len(tests)} file test, {len(objects)} oggetti.")
