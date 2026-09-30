import Foundation

/// A copy of `docs/appearance-fixtures.json`, the resolver vectors every notice
/// SDK runs. Embedded because the simulator cannot read the checkout directly
/// (a protected folder blocks on a permission prompt); refresh it when the doc
/// changes.
enum AppearanceFixtures {
    static let json = ##"""
{
  "description": "Shared resolver vectors for active_config.appearance. Every notice SDK runs these against its own resolver so all platforms read one served value the same way. `expected.radius` is in px or null when unset.",
  "cases": [
    {
      "name": "absent appearance is classic with nothing set",
      "input": null,
      "expected": {
        "style": "classic",
        "colors": {},
        "radius": null,
        "selection_control": null,
        "confirm_before_submit": false,
        "control_style": null
      }
    },
    {
      "name": "empty appearance is classic with nothing set",
      "input": {},
      "expected": {
        "style": "classic",
        "colors": {},
        "radius": null,
        "selection_control": null,
        "confirm_before_submit": false,
        "control_style": null
      }
    },
    {
      "name": "every recognised value is kept",
      "input": {
        "version": 1,
        "style": "soft",
        "template": "soft",
        "color_mode": "brand",
        "brand_color": "#2e7d32",
        "colors": {
          "background": "#0b1220",
          "tts_highlight_bg": "#FDE68A",
          "overlay": "#00000080"
        },
        "border_radius": 16,
        "selection_control": "radio",
        "confirm_before_submit": true
      },
      "expected": {
        "style": "soft",
        "colors": {
          "background": "#0b1220",
          "tts_highlight_bg": "#FDE68A",
          "overlay": "#00000080"
        },
        "radius": 16,
        "selection_control": "radio",
        "confirm_before_submit": true,
        "control_style": null
      }
    },
    {
      "name": "unrecognised values are dropped, never fatal",
      "input": {
        "style": "neon",
        "colors": {
          "background": "red",
          "text": "#12345",
          "link": "url(x)",
          "heading": "#fff",
          "sparkle": "#ffffff"
        },
        "selection_control": "toggle",
        "confirm_before_submit": "yes"
      },
      "expected": {
        "style": "classic",
        "colors": {
          "heading": "#fff"
        },
        "radius": null,
        "selection_control": null,
        "confirm_before_submit": false,
        "control_style": null
      }
    },
    {
      "name": "radius is clamped to the console range",
      "input": {
        "border_radius": 400
      },
      "expected": {
        "style": "classic",
        "colors": {},
        "radius": 28,
        "selection_control": null,
        "confirm_before_submit": false,
        "control_style": null
      }
    },
    {
      "name": "negative radius clamps to zero",
      "input": {
        "border_radius": -3
      },
      "expected": {
        "style": "classic",
        "colors": {},
        "radius": 0,
        "selection_control": null,
        "confirm_before_submit": false,
        "control_style": null
      }
    },
    {
      "name": "a non-object appearance is ignored",
      "input": "glass",
      "expected": {
        "style": "classic",
        "colors": {},
        "radius": null,
        "selection_control": null,
        "confirm_before_submit": false,
        "control_style": null
      }
    },
    {
      "name": "a switch control style is kept",
      "input": {
        "style": "minimal",
        "control_style": "switch"
      },
      "expected": {
        "style": "minimal",
        "colors": {},
        "radius": null,
        "selection_control": null,
        "control_style": "switch",
        "confirm_before_submit": false
      }
    },
    {
      "name": "an unknown control style is dropped",
      "input": {
        "control_style": "toggle"
      },
      "expected": {
        "style": "classic",
        "colors": {},
        "radius": null,
        "selection_control": null,
        "control_style": null,
        "confirm_before_submit": false
      }
    },
    {
      "name": "a midnight-era dark palette resolves like any other",
      "input": {
        "style": "classic",
        "template": "dark",
        "colors": {
          "background": "#0b1220",
          "text": "#e5e7eb"
        }
      },
      "expected": {
        "style": "classic",
        "colors": {
          "background": "#0b1220",
          "text": "#e5e7eb"
        },
        "radius": null,
        "selection_control": null,
        "confirm_before_submit": false,
        "control_style": null
      }
    }
  ],
  "layout_description": "Layout vectors: `input` is a served appearance, `expected` the layout after the style's defaults (glass: sheet on phones, collapsible sections, paired footer; every other style: none of these; checkboxes everywhere until `control_style` asks for switches). `max_width` and `logo_size` are px or null; `custom_css` is the kept CSS or null when refused.",
  "layout_cases": [
    {
      "name": "classic keeps the classic layout",
      "input": {},
      "expected": {
        "mobile_sheet": false,
        "desktop_position": "center",
        "dim_backdrop": true,
        "collapsible_sections": false,
        "paired_footer": false,
        "switch_control": false,
        "motion": true,
        "max_width": null,
        "logo_size": null,
        "text_scale": null,
        "custom_css": null
      }
    },
    {
      "name": "glass brings its own layout defaults",
      "input": {
        "style": "glass"
      },
      "expected": {
        "mobile_sheet": true,
        "desktop_position": "center",
        "dim_backdrop": true,
        "collapsible_sections": true,
        "paired_footer": true,
        "switch_control": false,
        "motion": true,
        "max_width": null,
        "logo_size": null,
        "text_scale": null,
        "custom_css": null
      }
    },
    {
      "name": "glass can float as a modal on phones",
      "input": {
        "style": "glass",
        "mobile_layout": "modal",
        "phone_footer": "stacked",
        "collapsible_sections": false,
        "control_style": "checkbox"
      },
      "expected": {
        "mobile_sheet": false,
        "desktop_position": "center",
        "dim_backdrop": true,
        "collapsible_sections": false,
        "paired_footer": false,
        "switch_control": false,
        "motion": true,
        "max_width": null,
        "logo_size": null,
        "text_scale": null,
        "custom_css": null
      }
    },
    {
      "name": "any style can dock, collapse and pair",
      "input": {
        "style": "minimal",
        "mobile_layout": "sheet",
        "collapsible_sections": true,
        "phone_footer": "paired",
        "control_style": "switch"
      },
      "expected": {
        "mobile_sheet": true,
        "desktop_position": "center",
        "dim_backdrop": true,
        "collapsible_sections": true,
        "paired_footer": true,
        "switch_control": true,
        "motion": true,
        "max_width": null,
        "logo_size": null,
        "text_scale": null,
        "custom_css": null
      }
    },
    {
      "name": "desktop position and backdrop",
      "input": {
        "desktop_position": "bottom-right",
        "backdrop": "none"
      },
      "expected": {
        "mobile_sheet": false,
        "desktop_position": "bottom-right",
        "dim_backdrop": false,
        "collapsible_sections": false,
        "paired_footer": false,
        "switch_control": false,
        "motion": true,
        "max_width": null,
        "logo_size": null,
        "text_scale": null,
        "custom_css": null
      }
    },
    {
      "name": "unknown layout values fall back to the style",
      "input": {
        "mobile_layout": "drawer",
        "desktop_position": "top",
        "backdrop": "blur",
        "phone_footer": "grid",
        "text_scale": "xl",
        "motion": "no"
      },
      "expected": {
        "mobile_sheet": false,
        "desktop_position": "center",
        "dim_backdrop": true,
        "collapsible_sections": false,
        "paired_footer": false,
        "switch_control": false,
        "motion": true,
        "max_width": null,
        "logo_size": null,
        "text_scale": null,
        "custom_css": null
      }
    },
    {
      "name": "sizes are clamped and motion can be off",
      "input": {
        "max_width": 5000,
        "logo_size": 2,
        "text_scale": "lg",
        "motion": false
      },
      "expected": {
        "mobile_sheet": false,
        "desktop_position": "center",
        "dim_backdrop": true,
        "collapsible_sections": false,
        "paired_footer": false,
        "switch_control": false,
        "motion": false,
        "max_width": 960,
        "logo_size": 16,
        "text_scale": "lg",
        "custom_css": null
      }
    },
    {
      "name": "custom css is kept when it passes the guard",
      "input": {
        "custom_css": "[data-redacto-part=\"accept-all\"] { border-radius: 0 !important; }"
      },
      "expected": {
        "mobile_sheet": false,
        "desktop_position": "center",
        "dim_backdrop": true,
        "collapsible_sections": false,
        "paired_footer": false,
        "switch_control": false,
        "motion": true,
        "max_width": null,
        "logo_size": null,
        "text_scale": null,
        "custom_css": "[data-redacto-part=\"accept-all\"] { border-radius: 0 !important; }"
      }
    },
    {
      "name": "custom css that closes the notice's scope early is refused whole",
      "input": {
        "custom_css": "a { color: red } } body { display: none !important } b {"
      },
      "expected": {
        "mobile_sheet": false,
        "desktop_position": "center",
        "dim_backdrop": true,
        "collapsible_sections": false,
        "paired_footer": false,
        "switch_control": false,
        "motion": true,
        "max_width": null,
        "logo_size": null,
        "text_scale": null,
        "custom_css": null
      }
    },
    {
      "name": "custom css with an escaped @import is refused whole",
      "input": {
        "custom_css": "@im\\70 ort url(x); a { color: red }"
      },
      "expected": {
        "mobile_sheet": false,
        "desktop_position": "center",
        "dim_backdrop": true,
        "collapsible_sections": false,
        "paired_footer": false,
        "switch_control": false,
        "motion": true,
        "max_width": null,
        "logo_size": null,
        "text_scale": null,
        "custom_css": null
      }
    }
  ],
  "dark_cases": [
    {
      "name": "auto dark swaps in the dark palette on a dark device",
      "input": {
        "auto_dark": true,
        "colors": {
          "background": "#ffffff"
        },
        "dark_colors": {
          "background": "#0b1220"
        }
      },
      "prefers_dark": true,
      "expected_colors": {
        "background": "#0b1220"
      }
    },
    {
      "name": "auto dark keeps the light palette on a light device",
      "input": {
        "auto_dark": true,
        "colors": {
          "background": "#ffffff"
        },
        "dark_colors": {
          "background": "#0b1220"
        }
      },
      "prefers_dark": false,
      "expected_colors": {
        "background": "#ffffff"
      }
    },
    {
      "name": "auto dark without a dark palette keeps the light one",
      "input": {
        "auto_dark": true,
        "colors": {
          "background": "#ffffff"
        }
      },
      "prefers_dark": true,
      "expected_colors": {
        "background": "#ffffff"
      }
    },
    {
      "name": "a dark palette is ignored while auto dark is off",
      "input": {
        "colors": {
          "background": "#ffffff"
        },
        "dark_colors": {
          "background": "#0b1220"
        }
      },
      "prefers_dark": true,
      "expected_colors": {
        "background": "#ffffff"
      }
    }
  ]
}
"""##

    static let object: [String: Any] = {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    }()
}
