# cocoapods-xcframework

This is a plugin for CococoaPods to create xcframeworks before actual installing.

Forked from [cocoapods-binary](https://github.com/leavez/cocoapods-binary).  
Dropped many featured and focused on creating xcframework.

## Installation

```ruby
gem 'cocoapods-xcframework', git: "https://github.com/muukii/cocoapods-xcframework", branch: "muukii/xc"
```

## Usage

```ruby
target "MyApp" do
  pod "Alamofire", binary: true
  pod "MondrianLayout", binary: true
end
```

## Known-issues

- No caching, every time creates xcframeworks on `pod install`
- No supports a module which contains its bundle resoucres.
- Can't build a module which no supports library-evolution.

## Author

Originally created by [leavez](https://github.com/leavez)
