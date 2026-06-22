# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProfileCssSanitizer do
  describe '.call' do
    it 'scopes safe selectors to the profile root' do
      result = described_class.call('.account__header, h2 { color: #f00; margin: 1rem; }', '#profile_kyle__kyspace_net')

      expect(result)
        .to eq('#profile_kyle__kyspace_net .account__header, #profile_kyle__kyspace_net h2 { color: #f00; margin: 1rem; }')
    end

    it 'scopes page-level selectors to the profile root' do
      result = described_class.call(<<~CSS, '#profile_kyle__kyspace_net')
        body { color: red; }
        html .columns-area { background: transparent; }
        :root .navigation-panel { color: #0ff; }
      CSS

      expect(result)
        .to eq("#profile_kyle__kyspace_net { color: red; }\n#profile_kyle__kyspace_net .columns-area { background: transparent; }\n#profile_kyle__kyspace_net .navigation-panel { color: #0ff; }")
    end

    it 'allows page takeover styles while dropping unsafe at-rules' do
      result = described_class.call(<<~CSS, '#profile_kyle__kyspace_net')
        @import url("https://example.com/x.css");
        body { background-image: url("https://example.com/x.png"); position: fixed; z-index: 9999; cursor: crosshair; }
        .bio { display: none; opacity: 0; pointer-events: none; }
      CSS

      expect(result)
        .to eq("#profile_kyle__kyspace_net { background-image: url(\"https://example.com/x.png\"); position: fixed; z-index: 9999; cursor: crosshair; }\n#profile_kyle__kyspace_net .bio { display: none; opacity: 0; pointer-events: none; }")
    end

    it 'keeps safe media blocks scoped to the profile root' do
      result = described_class.call('@media (width < 600px) { .bio { font-size: 14px; } }', '#profile_kyle__kyspace_net')

      expect(result)
        .to eq("@media (width < 600px) {\n#profile_kyle__kyspace_net .bio { font-size: 14px; }\n}")
    end

    it 'allows keyframes and root ampersand selectors' do
      result = described_class.call(<<~CSS, '#profile_kyle__kyspace_net')
        @keyframes sparkle { from { opacity: 0.4; } to { opacity: 1; } }
        &.is-composing { animation: sparkle 1s infinite alternate; }
      CSS

      expect(result)
        .to eq("@keyframes sparkle {\nfrom { opacity: 0.4; } to { opacity: 1; }\n}\n#profile_kyle__kyspace_net.is-composing { animation: sparkle 1s infinite alternate; }")
    end

    it 'rejects style escape and script-like CSS values' do
      result = described_class.call(<<~CSS, '#profile_kyle__kyspace_net')
        .bio { color: blue; }
        .bad { background-image: url("javascript:alert(1)"); }
      CSS

      expect(result).to eq('')
      expect(described_class.call('.bio { color: blue; } </style><script>alert(1)</script>', '#profile_kyle__kyspace_net')).to eq('')
    end
  end
end
