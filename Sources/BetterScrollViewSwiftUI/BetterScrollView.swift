/*
 * FILE:	BetterScrollView.swift
 * DESCRIPTION:	BetterScrollViewSwiftUI: ScrollView with Scroll Offset and Direction
 * DATE:	Sat, May 28 2022
 * UPDATED:	Sat, May 28 2022
 * AUTHOR:	Kouichi ABE (WALL) / 阿部康一
 * E-MAIL:	kouichi@MagickWorX.COM
 * URL:		https://www.MagickWorX.COM/
 * COPYRIGHT:	(c) 2022 阿部康一／Kouichi ABE (WALL)
 * LICENSE:	The 2-Clause BSD License (See LICENSE.txt)
 */

import SwiftUI
import Combine

/*
 * Reference:
 * Mastering ScrollView in SwiftUI | Swift with Majid
 * https://swiftwithmajid.com/2020/09/24/mastering-scrollview-in-swiftui/
 *
 * Reference:
 * SwiftUI ScrollView Scroll Offset | Swift UI recipes
 * https://swiftuirecipes.com/blog/swiftui-scrollview-scroll-offset
 *
 * Reference:
 * ios - SwiftUI - Detect when ScrollView has finished scrolling? - Stack Overflow
 * https://stackoverflow.com/questions/65062590/swiftui-detect-when-scrollview-has-finished-scrolling
 */


public typealias ScrollEndedHandler = (CGPoint, ScrollDirection) -> Void

public struct BetterScrollView<Content>: View where Content: View
{
  private let axes: Axis.Set
  private let showsIndicators: Bool
  @Binding public var contentOffset: CGPoint
  @Binding public var scrollDirection: ScrollDirection
  private let content: (ScrollViewProxy) -> Content

  private var onScrollEnded: ScrollEndedHandler? = nil

  @State private var previousOffset: CGPoint = .zero
  @Namespace private var scrollSpace

  @StateObject private var scrollViewHelper: ScrollViewHelper = .init()

  public init(axes: Axis.Set = .vertical,
       showsIndicators: Bool = true,
       contentOffset: Binding<CGPoint>,
       scrollDirection: Binding<ScrollDirection>,
       @ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {
    self.axes = axes
    self.showsIndicators = showsIndicators
    self._contentOffset = contentOffset
    self._scrollDirection = scrollDirection
    self.content = content
  }

  public var body: some View {
    ScrollView(axes, showsIndicators: showsIndicators) {
      ScrollViewReader { proxy in
        content(proxy)
          .background {
            GeometryReader { geometry in
              let offset = geometry.frame(in: .named(scrollSpace)).origin
              Color.clear
                .preference(key: ScrollOffsetPreferenceKey.self, value: offset)
            }
          }
      }
    }
    .coordinateSpace(name: scrollSpace)
    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
      self.previousOffset = self.contentOffset
      self.contentOffset = value
      self.scrollDirection = self.guessScrollDirection()
      self.scrollViewHelper.currentOffset = value
    }
    .onReceive(scrollViewHelper.$offsetAtScrollEnd) { value in
      self.onScrollEnded?(value, self.scrollDirection)
    }
  }
}

extension BetterScrollView
{
  public func onScrollEnded(_ action: @escaping ScrollEndedHandler) -> Self {
    var copy = self
    copy.onScrollEnded = action
    return copy
  }
}

final class ScrollViewHelper: ObservableObject
{
  @Published var currentOffset: CGPoint = .zero
  @Published var offsetAtScrollEnd: CGPoint = .zero

  private var cancellable: AnyCancellable?

  init() {
    cancellable = AnyCancellable(
      $currentOffset
        .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
        .dropFirst()
        .assign(to: \.offsetAtScrollEnd, on: self)
     )
  }
}

public enum ScrollDirection: Int, CustomStringConvertible
{
  case unknown
  case right
  case left
  case up
  case down

  public var description: String {
    switch self {
      case .unknown: return "unknown"
      case .right:   return "right"
      case .left:    return "left"
      case .up:      return "up"
      case .down:    return "down"
    }
  }
}

extension BetterScrollView
{
  private func guessScrollDirection() -> ScrollDirection {
    let px = previousOffset.x
    let py = previousOffset.y
    let cx = contentOffset.x
    let cy = contentOffset.y
    let w = px - cx
    let h = py - cy
    switch(w, h) {
      case (0..., -30...30):   return .right
      case (...0, -30...30):   return .left
      case (-100...100, ...0): return .up
      case (-100...100, 0...): return .down
      default:                 return .unknown
    }
  }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey
{
  typealias Value = CGPoint

  static var defaultValue: Value = .zero

  static func reduce(value: inout Value, nextValue: () -> Value) {
    /*
     * XXX:
     * We have gotten the  negative coordinates of child view inside parent one.
     * So we revise it to the positive one.
     * Is it correct?
     */
    let x = value.x - nextValue().x
    let y = value.y - nextValue().y
    value.x = abs(x)
    value.y = abs(y)
  }
}


// MARK: - Preview
private struct PreviewContentView: View
{
  @State private var contentOffset: CGPoint = .zero
  @State private var scrollViewProxy: ScrollViewProxy?
  @State private var angle: CGFloat = 0

  @State private var scrollDirection: ScrollDirection = .unknown
  @State private var stoppedPosition: CGPoint = .zero

  private var showsSidebar: Bool {
    return angle == 0
  }

  var body: some View {
    GeometryReader { geometry in
      let width: CGFloat = geometry.size.width
      let height: CGFloat = geometry.size.height
      BetterScrollView(axes: .horizontal, showsIndicators: false, contentOffset: $contentOffset, scrollDirection: $scrollDirection) { proxy in
        HStack(spacing: 0) {
          Rectangle()
            .frame(width: 80, height: height)
            .foregroundColor(.mint)
            .id(1)
            .rotation3DEffect(.degrees(angle), axis: (x: 0.0, y: 1.0, z: 0.0), anchor: .trailing)
          NavigationView {
            VStack {
              Spacer()
              Text("Hello ScrollView").font(.title)
              Spacer()
            }
            .frame(width: width, height: height)
            .background(Color.indigo)
            .toolbar {
              ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                  self.toggleSidebar()
                }) {
                  Image(systemName: "line.3.horizontal")
                    .imageScale(.large)
                    .foregroundColor(.primary)
                    .rotationEffect(.degrees(angle - 90))
                }
              }
            }
            .overlay {
              Group {
                if showsSidebar {
                  Color.white
                    .opacity(showsSidebar ? 0.01 : 0.0)
                    .onTapGesture {
                      self.toggleSidebar()
                    }
                }
                else {
                  Color.clear
                }
              }
            }
          }
          .frame(width: width, height: height)
          .id(2)
        }
        .onChange(of: contentOffset) { offset in
          self.angle = -((90.0 * offset.x) / 80.0)
        }
        .onAppear {
          self.scrollViewProxy = proxy
          self.toggleSidebar()
        }
      }
      .onScrollEnded {
        (offset, direction) in
        self.stoppedPosition = offset
      }
    }
    .onAppear {
      UIScrollView.appearance().bounces = false
    }
    .overlay(alignment: .topTrailing) {
      Text(String(format: "angle: %.1f, offset: (%.1f, %.1f) \n[%@] stopped: (%.1f, %.1f) ",angle,contentOffset.x,contentOffset.y, scrollDirection.description, stoppedPosition.x, stoppedPosition.y))
    }
  }

  private func toggleSidebar() {
    withAnimation {
      self.scrollViewProxy?.scrollTo(self.showsSidebar ? 2 : 1, anchor: .leading)
    }
  }
}


// MARK: - Preview
struct BetterScrollView_Previews: PreviewProvider
{
  static var previews: some View {
    PreviewContentView()
  }
}
