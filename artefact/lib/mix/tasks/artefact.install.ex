# SPDX-FileCopyrightText: 2026 artefactory contributors <https://github.com/diffo-dev/artefactory/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Artefact.Install.Docs do
  @moduledoc false

  def short_doc, do: "Installs Artefact"
  def example, do: "mix igniter.install artefact"

  def long_doc do
    """
    #{short_doc()}

    ## Example

    ```bash
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Artefact.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"
    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :artefact,
        example: __MODULE__.Docs.example()
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.Project.Formatter.import_dep(:artefact)
    end
  end
else
  defmodule Mix.Tasks.Artefact.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"
    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'artefact.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
