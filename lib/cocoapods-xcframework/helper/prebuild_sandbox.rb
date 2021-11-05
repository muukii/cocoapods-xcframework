require_relative "names"

module Pod
  class PrebuildSandbox < Sandbox

    # [String] standard_sandbox_path
    def self.from_standard_sanbox_path(path)
      prebuild_sandbox_path = Pathname.new(path).realpath + "cocoapods-xcframework"
      self.new(prebuild_sandbox_path)
    end

    def self.from_standard_sandbox(sandbox)
      self.from_standard_sanbox_path(sandbox.root)
    end

    def standard_sanbox_path
      self.root.parent
    end

  end
end
