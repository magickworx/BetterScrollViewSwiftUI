# BetterScrollViewSwiftUI

This package provides you a custom ScrollView and you can get the following featrues.

- Content offset
- Scroll direction
- End of scroll ((you can get the last content offset and scroll direction together)
- ScrollViewProxy

You can add this package on Xcode.
See [documentation](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app).


## How to Use

You can just import BetterScrollViewSwiftUI to use the package.

```swift
  @State private var contentOffset: CGPoint = .zero
  @State private var scrollDirection: ScrollDirection = .unknown

  BetterScrollView(contentOffset: $contentOffset, scrollDirection: $scrollDirection) { proxy in
    // your code here
  }
  .onScrollEnded {
    (offset, direction) in
    // your code here
  }
```

## License

This package is licensed under [BSD License](LICENSE)
