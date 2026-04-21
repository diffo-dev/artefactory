# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

# Integration tests require a live DozerDB instance.
# Run with: mix test --include integration
# Default (mix test) skips them.
ExUnit.configure(exclude: [:integration])
ExUnit.start()
