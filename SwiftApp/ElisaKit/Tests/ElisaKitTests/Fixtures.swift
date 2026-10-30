import Foundation

enum Fixtures {
    /// A download from the web app's hidden state link (ui.ts downloadState), trimmed: a full
    /// profile mid-session at blue, a second profile saved by an old version with only a name
    /// and an icon, and one finished session at yellow.
    static let webExport = Data("""
    {
      "state": {
        "profiles": {
          "100": {
            "id": 100, "name": "Elisa", "icon": "fa-paw", "target_number": 25,
            "show_chord_mode": "black_only", "reveal_chord_mode": "always",
            "chord_display_mode": "shapes_and_letters", "single_note_mode": "white_only_on_black",
            "single_note_correctness_mode": "only_correct", "persist_reaction_face": true,
            "enable_onboarding_hints": true, "color_scheme": "light", "chord_selection_mode": "random",
            "stats": {
              "current_chord": "blue", "start_time": 1793380000.5, "updated_time": 1793380100.25,
              "correct": 3, "identifications": 4,
              "confusion_matrix": {"red": {"red": 2}, "blue": {"blue": 1, "red": 1}},
              "notes": {"correct": 1, "identifications": 1, "confusion_matrix": {"gray": {"C#4": {"C#4": 1}}}},
              "done": false
            },
            "current_chord": "blue", "current_instrument": "guitar", "streak": 7
          },
          "101": {"id": 101, "name": "Papá", "icon": "fa-user"}
        },
        "current_chord": "blue",
        "current_profile": 100
      },
      "history": {
        "100": {
          "yellow": [{
            "current_chord": "yellow", "start_time": 1793300000, "updated_time": 1793300500,
            "correct": 18, "identifications": 20,
            "confusion_matrix": {"red": {"red": 9, "yellow": 1}, "yellow": {"yellow": 9, "red": 1}},
            "notes": {"correct": 0, "identifications": 0, "confusion_matrix": {}},
            "done": true
          }]
        }
      }
    }
    """.utf8)
}
