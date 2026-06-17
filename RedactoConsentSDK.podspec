Pod::Spec.new do |s|
  s.name         = "RedactoConsentSDK"
  s.version      = "1.1.0"
  s.summary      = "Redacto Consent SDK for iOS."
  s.description  = "Native Swift SDK for rendering and submitting user consent with Redacto CMP, including the Privacy Center."
  s.homepage     = "https://github.com/redactolabs/consent-sdk-ios"
  s.license      = { :type => "Apache-2.0", :file => "LICENSE" }
  s.author       = { "Redacto" => "support@redacto.io" }
  s.platform     = :ios, "16.0"
  s.swift_versions = ["5.9"]
  s.source       = { :git => "https://github.com/redactolabs/consent-sdk-ios.git", :tag => "v1.1.0" }
  s.source_files = "Sources/RedactoConsentSDK/**/*.{swift}"
  s.resource_bundles = {
    "RedactoConsentSDK" => ["Sources/RedactoConsentSDK/PrivacyCenter/Localization/Resources/**/*.lproj/*.strings"]
  }
end
