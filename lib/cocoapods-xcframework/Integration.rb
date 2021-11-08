require_relative "helper/podfile_options"
require_relative "helper/feature_switches"
require_relative "helper/prebuild_sandbox"
require_relative "helper/names"
require_relative "helper/target_checker"
require 'pp'

# Let cocoapods use the prebuild framework files in install process.
#
# the code only effect the second pod install process.
#
module Pod
  class Installer
  
    # Modify specification to use only the prebuild framework after analyzing
    old_method2 = instance_method(:resolve_dependencies)
    define_method(:resolve_dependencies) do
    
      # call original
      old_method2.bind(self).()

      # ...
      # ...
      # ...
      # after finishing the very complex orginal function

      # check the pods
      # Although we have did it in prebuild stage, it's not sufficient.
      # Same pod may appear in another target in form of source code.
      # Prebuild.check_one_pod_should_have_only_one_target(self.prebuild_pod_targets)
      self.validate_every_pod_only_have_one_form

      # prepare
      cache = []

      specs = self.analysis_result.specifications

      prebuilt_specs = (specs.select do |spec|
        self.prebuild_pod_names.include? spec.root.name
      end)

      Pod::UI.puts "Modify specs"

      prebuilt_specs.each do |spec|

        p spec
        Pod::UI.puts "Before"
        pp spec.attributes_hash

        # Use the prebuild framworks as vendered frameworks
        # get_corresponding_targets
        targets = Pod.fast_get_targets_for_pod_name(spec.root.name, self.pod_targets, cache)
        targets.each do |target|

          framework_name = target.name

          # case of the spec has module_name property
          if spec.attributes_hash["module_name"] != nil 
            framework_name = spec.attributes_hash["module_name"].to_s
          end

          if spec.parent != nil && spec.parent.attributes_hash["module_name"] != nil 
            framework_name = spec.parent.attributes_hash["module_name"].to_s
          end


          platform = target.platform.name.to_s
          if spec.attributes_hash[platform] == nil
            spec.attributes_hash[platform] = {}
          end
          spec.attributes_hash[platform]["vendored_frameworks"] = ["#{framework_name}.xcframework"]
          spec.attributes_hash[platform]["preserve_paths"] = ["#{framework_name}.xcframework"]
        end
        # Clean the source files
        # we just add the prebuilt framework to specific platform and set no source files
        # for all platform, so it doesn't support the sence that 'a pod perbuild for one
        # platform and not for another platform.'

        def deleteProperty(spec:, name:)
          spec.attributes_hash.delete(name)
          ["ios", "watchos", "tvos", "osx"].each do |plat|
            if spec.attributes_hash[plat] != nil
              spec.attributes_hash[plat].delete(name)
            end
          end
        end

        deleteProperty(spec: spec, name: "source_files")
        deleteProperty(spec: spec, name: "header_dir")
        deleteProperty(spec: spec, name: "exclude_files")
        deleteProperty(spec: spec, name: "module_name")
        deleteProperty(spec: spec, name: "public_header_files")
        deleteProperty(spec: spec, name: "compiler_flags")

        # to remove the resurce bundle target.
        # When specify the "resource_bundles" in podspec, xcode will generate a bundle
        # target after pod install. But the bundle have already built when the prebuit
        # phase and saved in the framework folder. We will treat it as a normal resource
        # file.
        # https://github.com/leavez/cocoapods-binary/issues/29
        if spec.attributes_hash["resource_bundles"]
          bundle_names = spec.attributes_hash["resource_bundles"].keys
          spec.attributes_hash["resource_bundles"] = nil
          spec.attributes_hash["resources"] ||= []
          spec.attributes_hash["resources"] += bundle_names.map { |n| n + ".bundle" }
        end

        # to avoid the warning of missing license
        spec.attributes_hash["license"] = {}

        Pod::UI.puts "After.Spec"        
        pp spec.attributes_hash
        Pod::UI.puts "After.Spec.parent"   
        pp spec.parent.attributes_hash unless spec.parent.nil?
      end
    end

    # Override the download step to skip download and prepare file in target folder
    old_method = instance_method(:install_source_of_pod)
    define_method(:install_source_of_pod) do |pod_name|

      # copy from original
      pod_installer = create_pod_installer(pod_name)
      # \copy from original

      if self.prebuild_pod_names.include? pod_name

      else
        pod_installer.install!
      end

      # copy from original
      @installed_specs.concat(pod_installer.specs_by_platform.values.flatten.uniq)
      # \copy from original
    end
  end
end
