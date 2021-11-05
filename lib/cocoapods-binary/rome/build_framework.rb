require "xcpretty"
require 'fileutils'

CONFIGURATION = "Release"

#  Build specific target to framework file
#  @param [PodTarget] target
#         a specific pod target
#
def build_for_iosish_platform(
  sandbox:,
  build_dir:,
  output_path:,
  target:
)

  # deployment_target = target.platform.deployment_target.to_s
  target_label = target.label # name with platform if it's used in multiple platforms

  Pod::UI.puts "Prebuilding #{target_label} as XCFramework -> #{output_path}"

  shell = createXCFramewrok(
    outputPath: output_path,
    buildDirectory: build_dir,
    moduleName: target.product_module_name,
    projectName: sandbox.project_path.realdirpath,
    scheme: target_label,
    configuration: CONFIGURATION
  )

end

def createXCFramewrok(
  outputPath:,
  buildDirectory:,
  moduleName:,
  projectName:,
  scheme:, 
  configuration:
)

  options = []

  options.push("ENABLE_BITCODE=YES")
  options.push("BITCODE_GENERATION_MODE=bitcode")
  options.push("OTHER_CFLAGS=-fembed-bitcode")
  options.push("BUILD_LIBRARY_FOR_DISTRIBUTION=true")
  options.push("SKIP_INSTALL=NO")
  options.push("DEBUG_INFORMATION_FORMAT=dwarf-with-dsym")
  options.push("ONLY_ACTIVE_ARCH=NO")

  # FileUtils.mkdir_p

  xcodebuild(
    projectName: projectName,
    scheme: scheme,
    destination: "generic/platform=iOS",
    sdk: "iphoneos",
    archivePath: "#{buildDirectory}/#{moduleName}/ios.xcarchive",
    otherOptions: options
  )

  xcodebuild(
    projectName: projectName,
    scheme: scheme,
    destination: "generic/platform=iOS Simulator",
    sdk: "iphonesimulator",
    archivePath: "#{buildDirectory}/#{moduleName}/ios-simulator.xcarchive",
    otherOptions: options
  )

  bitcodePaths = Dir.glob("#{buildDirectory}/#{moduleName}/ios.xcarchive/**/*.bcsymbolmap")
  
  # https://github.com/madsolar8582/SLRNetworkMonitor/blob/e415fc6399aa164ab8b147a6476630b2418d1d75/release.sh#L73

  archiveRoot = buildDirectory
  project = projectName

  args = %W(-output "#{outputPath}/#{moduleName}.xcframework")

  args.push("-framework \"#{buildDirectory}/#{moduleName}/ios.xcarchive/Products/Library/Frameworks/#{moduleName}.framework\"")
  args.push("-debug-symbols \"#{buildDirectory}/#{moduleName}/ios.xcarchive/dSYMs/#{moduleName}.framework.dSYM\"")
  args += bitcodePaths.map { |e| 
    "-debug-symbols \"#{e}\""
  }
 
  args.push("-framework \"#{buildDirectory}/#{moduleName}/ios-simulator.xcarchive/Products/Library/Frameworks/#{moduleName}.framework\"")
  args.push("-debug-symbols \"#{buildDirectory}/#{moduleName}/ios-simulator.xcarchive/dSYMs/#{moduleName}.framework.dSYM\"")

  command = "xcodebuild -create-xcframework #{args.join(" \\\n")}"

  # puts "Creates xcframework with #{command}"
  
  log = `#{command} 2>&1`
    
end

def build_for_macos_platform(sandbox, build_dir, target, flags, configuration, build_xcframework = false)
  target_label = target.cocoapods_target_label
  xcodebuild(sandbox, target_label, flags, configuration)

  spec_names = target.specs.map { |spec| [spec.root.name, spec.root.module_name] }.uniq
  spec_names.each do |root_name, module_name|
    if build_xcframework
      framework = "#{build_dir}/#{configuration}/#{root_name}/#{module_name}.framework"
      build_xcframework([framework], build_dir, module_name)
    end
  end
end

def xcodebuild(
  projectName:,
  scheme:,
  destination:,
  sdk:,
  archivePath:,
  otherOptions:
)
  args = %W(-project "#{projectName}" -scheme "#{scheme}" -configuration "#{CONFIGURATION}" -sdk "#{sdk}" -destination "#{destination}" -archivePath "#{archivePath}")
  args += otherOptions
  log = `xcodebuild archive #{args.join(" ")} 2>&1`
  exit_code = $?.exitstatus  # Process::Status
  is_succeed = (exit_code == 0)

  if !is_succeed
    begin
      if log.include?("** BUILD FAILED **")
        # use xcpretty to print build log
        # 64 represent command invalid. http://www.manpagez.com/man/3/sysexits/
        printer = XCPretty::Printer.new({ :formatter => XCPretty::Simple, :colorize => "auto" })
        log.each_line do |line|
          printer.pretty_print(line)
        end
      else
        raise "shouldn't be handle by xcpretty"
      end
    rescue
      puts log.red
    end
  end
  [is_succeed, log]
end

module Pod
  class Prebuild
    def self.build_xcframework(
      sandbox_root_path:,
      target:,
      output_path:
    )
      Pod::UI.puts "Build XCFramework"

      return if target.nil?

      sandbox_root = Pathname(sandbox_root_path)
      sandbox = Pod::Sandbox.new(sandbox_root)
      build_dir = self.build_dir(sandbox_root)

      # -- build the framework
      case target.platform.name
      when :ios
        build_for_iosish_platform(
          sandbox: sandbox,
          build_dir: build_dir,
          output_path: output_path,
          target: target
        )
      when :osx
        xcodebuild(
          sandbox,
          target.label,
          "macosx",
          nil,
          custom_build_options
        )
        # when :tvos then build_for_iosish_platform(sandbox, build_dir, target, 'appletvos', 'appletvsimulator')
      when :watchos
        build_for_iosish_platform(
          sandbox,
          build_dir,
          output_path,
          target,
          "watchos",
          "watchsimulator",
          true,
          custom_build_options,
          custom_build_options_simulator
        )
      else raise "Unsupported platform for '#{target.name}': '#{target.platform.name}'"
      end

      raise Pod::Informative, "The build directory was not found in the expected location." unless build_dir.directory?
    end

    def self.remove_build_dir(sandbox_root)
      path = build_dir(sandbox_root)
      path.rmtree if path.exist?
    end

    private

    def self.build_dir(sandbox_root)
      # don't know why xcode chose this folder
      sandbox_root.parent + "build"
    end
  end
end
