// swift-tools-version: 6.0
//
// FokusKit — Fokus'un native katmanları. Bağımlılık yönü web'deki gibidir:
//   FokusDomain  ← hiçbir şeye bağlı değil (Foundation + CryptoKit)
//   FokusData    → FokusDomain (SwiftData, CloudKit mirroring, AuthenticationServices)
//   FokusDesign  → FokusDomain (SwiftUI tokenları, fontlar, ortak bileşenler)
// Uygulama hedefi (ios/Fokus) yalnızca kompozisyon + ekranlardır.
import PackageDescription

let package = Package(
    name: "FokusKit",
    defaultLocalization: "tr",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "FokusDomain", targets: ["FokusDomain"]),
        .library(name: "FokusData", targets: ["FokusData"]),
        .library(name: "FokusDesign", targets: ["FokusDesign"]),
    ],
    targets: [
        .target(name: "FokusDomain"),
        .target(
            name: "FokusData",
            dependencies: ["FokusDomain"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "FokusDesign",
            dependencies: ["FokusDomain"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "FokusDomainTests", dependencies: ["FokusDomain"]),
        .testTarget(name: "FokusDataTests", dependencies: ["FokusData", "FokusDomain"]),
        .testTarget(name: "FokusDesignTests", dependencies: ["FokusDesign"]),
    ],
    swiftLanguageModes: [.v6]
)
