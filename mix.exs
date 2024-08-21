defmodule TransitData.MixProject do
  use Mix.Project

  def project do
    [
      app: :transit_data,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_add_deps: :app_tree,
        flags: [
          :unmatched_returns
        ]
      ],
      test_coverage: [tool: LcovEx]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:atomic_map, "~> 0.9.3"},
      {:csv, "~> 3.2"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:hackney, "~> 1.20"},
      {:jaxon, "~> 2.0"},
      {:stream_gzip, "~> 0.4.2"},
      {:sweet_xml, "~> 0.7.4"},
      # TEST-ENV DEPS
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:lcov_ex, "~> 0.3", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0", only: :test},
      # Provided by Mix.install invocation in the notebook.
      # We only need to directly get this dep when running tests.
      {:tz, "~> 0.26.5", only: [:test]}
    ]
  end
end
