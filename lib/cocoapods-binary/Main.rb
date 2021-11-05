# encoding: UTF-8
require_relative "helper/podfile_options"
require_relative "tool/tool"

module Pod
  class Podfile
    module DSL

      # Don't remove source code of prebuilt pods
      # It may speed up the pod install if git didn't
      # include the `Pods` folder
      def keep_source_code_for_prebuilt_frameworks!
        DSL.dont_remove_source_code = true
      end

      private

      class_attr_accessor :dont_remove_source_code
      dont_remove_source_code = false

    end
  end
end

Pod::HooksManager.register("cocoapods-binary", :pre_install) do |installer_context|
  require_relative "helper/feature_switches"
  if Pod.is_prebuild_stage
    next
  end

  # [Check Environment]
  # check user_framework is on
  podfile = installer_context.podfile
  podfile.target_definition_list.each do |target_definition|
    next if target_definition.prebuild_framework_pod_names.empty?
    if not target_definition.uses_frameworks?
      STDERR.puts "[!] Cocoapods-binary requires `use_frameworks!`".red
      exit
    end
  end

  # -- step 1: prebuild framework ---
  # Execute a sperated pod install, to generate targets for building framework,
  # then compile them to framework files.
  require_relative "helper/prebuild_sandbox"
  require_relative "Prebuild"

  Pod::UI.puts "🚀  Prebuild frameworks"

  # Fetch original installer (which is running this pre-install hook) options,
  # then pass them to our installer to perform update if needed
  # Looks like this is the most appropriate way to figure out that something should be updated

  update = nil
  repo_update = nil

  include ObjectSpace
  ObjectSpace.each_object(Pod::Installer) { |installer|
    update = installer.update
    repo_update = installer.repo_update
  }

  # control features
  Pod.is_prebuild_stage = true
  Pod::Podfile::DSL.enable_prebuild_patch true  # enable sikpping for prebuild targets
  Pod::Installer.force_disable_integration true # don't integrate targets
  Pod::Config.force_disable_write_lockfile true # disbale write lock file for perbuild podfile
  Pod::Installer.disable_install_complete_message true # disable install complete message

  # make another custom sandbox
  standard_sandbox = installer_context.sandbox
  prebuild_sandbox = Pod::PrebuildSandbox.from_standard_sandbox(standard_sandbox)

  # get the podfile for prebuild
  prebuild_podfile = Pod::Podfile.from_ruby(podfile.defined_in_file)

  # install
  lockfile = installer_context.lockfile
  binary_installer = Pod::Installer.new(prebuild_sandbox, prebuild_podfile, lockfile)

  if binary_installer.have_exact_prebuild_cache? && !update
    binary_installer.install_when_cache_hit!
  else
    binary_installer.update = update
    binary_installer.repo_update = repo_update
    binary_installer.install!
  end

  # reset the environment
  Pod.is_prebuild_stage = false
  Pod::Installer.force_disable_integration false
  Pod::Podfile::DSL.enable_prebuild_patch false
  Pod::Config.force_disable_write_lockfile false
  Pod::Installer.disable_install_complete_message false
  Pod::UserInterface.warnings = [] # clean the warning in the prebuild step, it's duplicated.

  # -- step 2: pod install ---
  # install
  Pod::UI.puts "\n"
  Pod::UI.puts "🤖  Pod Install"
  require_relative "Integration"
  # go on the normal install step ...
end
