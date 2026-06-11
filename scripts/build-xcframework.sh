#!/bin/bash

set -eou pipefail

sdks=( macosx ) #ADGUARD: we build for macosx only


rm -rf Carthage/
mkdir Carthage

ALL_SDKS=$(xcodebuild -showsdks)

generate_xcframework() {
    local scheme="$1"
    local suffix="${2:-}"
    local MACH_O_TYPE="${3-mh_dylib}"
    local configuration_suffix="${4-}"
    local createxcframework="xcodebuild -create-xcframework "
    local GCC_GENERATE_DEBUGGING_SYMBOLS="YES"
    
    local resolved_configuration="Release$configuration_suffix"
    local resolved_product_name="$scheme$configuration_suffix"
    local OTHER_LDFLAGS=""

    if [ "$MACH_O_TYPE" = "staticlib" ]; then
        #For static framework we disabled symbols because they are not distributed in the framework causing warnings.
        GCC_GENERATE_DEBUGGING_SYMBOLS="NO"
    fi
    
    rm -rf Carthage/DerivedData
    
    for sdk in "${sdks[@]}"; do
        if grep -q "${sdk}" <<< "$ALL_SDKS"; then

            ## watchos, watchsimulator dont support make_mergeable: ld: unknown option: -make_mergeable
            if [[ "$sdk" == "watchos" || "$sdk" == "watchsimulator" ]]; then
                OTHER_LDFLAGS=""
            elif [ "$MACH_O_TYPE" != "staticlib" ]; then
                OTHER_LDFLAGS="-Wl,-make_mergeable"
            fi

            xcodebuild archive \
                -project Sentry.xcodeproj/ \
                -scheme "$scheme" \
                -configuration "$resolved_configuration" \
                -sdk "$sdk" \
                -archivePath "./Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive" \
                CODE_SIGNING_REQUIRED=NO \
                SKIP_INSTALL=NO \
                CODE_SIGN_IDENTITY= \
                CARTHAGE=YES \
                MACH_O_TYPE="$MACH_O_TYPE" \
                ENABLE_CODE_COVERAGE=NO \
                GCC_GENERATE_DEBUGGING_SYMBOLS="$GCC_GENERATE_DEBUGGING_SYMBOLS" \
                OTHER_LDFLAGS="$OTHER_LDFLAGS"
                 
            local frameworkPath="Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive/Products/Library/Frameworks/${resolved_product_name}.framework"

            if [ "$MACH_O_TYPE" = "staticlib" ]; then
                # ADGUARD: Sentry is a mixed Objective-C + Swift module. The only reliable way
                # to ship it as a *static* library (for SwiftPM/Xcode consumers) is a static
                # framework: the binary inside is already an `ar` static archive (built with
                # MACH_O_TYPE=staticlib), wrapped in a .framework so the Swift module, the
                # generated Sentry-Swift.h bridge and the module map are all shipped together.

                local infoPlist="${frameworkPath}/Info.plist"
                if [ ! -e "$infoPlist" ]; then
                    infoPlist="${frameworkPath}/Resources/Info.plist"
                fi
                # This workaround is necessary to make the Sentry static framework work.
                # More information in here: https://github.com/getsentry/sentry-cocoa/issues/3769
                # The version 100 seems to work with all Xcode up to 15.4
                plutil -replace "MinimumOSVersion" -string "100.0" "$infoPlist"

                # Drop the binary .swiftmodule files: they are locked to the exact compiler
                # version that built them, so a consumer on a different toolchain would fail
                # with "this SDK is not supported by the compiler". Keeping only the textual
                # .swiftinterface files lets the consumer rebuild the module from the interface.
                local swiftModuleDir="${frameworkPath}/Modules/${resolved_product_name}.swiftmodule"
                if [ ! -d "$swiftModuleDir" ]; then
                    swiftModuleDir="${frameworkPath}/Versions/Current/Modules/${resolved_product_name}.swiftmodule"
                fi
                if [ -d "$swiftModuleDir" ]; then
                    rm -f "${swiftModuleDir}"/*.swiftmodule
                fi

                createxcframework+="-framework ${frameworkPath} "
            else
                createxcframework+="-framework ${frameworkPath} "

                if [ -d "Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive/dSYMs/${resolved_product_name}.framework.dSYM" ]; then
                    # Has debug symbols
                    createxcframework+="-debug-symbols $(pwd -P)/Carthage/archive/${scheme}${suffix}/${sdk}.xcarchive/dSYMs/${resolved_product_name}.framework.dSYM "
                fi
            fi
        else
            echo "${sdk} SDK not found"
        fi
    done
    #ADGUARD: Removed Mac Catalist

    createxcframework+="-output Carthage/${scheme}${suffix}.xcframework"
    $createxcframework
}

generate_xcframework "Sentry" "" staticlib # ADGUARD: we need only static library framework
