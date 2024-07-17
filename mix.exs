defmodule TransitData.MixProject do
  use Mix.Project

  def project do
    [
      app: :transit_data,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:atomic_map, "~> 0.9.3"},
      {:csv, "~> 3.2"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:hackney, "~> 1.20"},
      # Provided by Mix.install invocation in the notebook
      # {:tzdata, "~> 1.1"},
      {:jaxon, "~> 2.0"},
      {:stream_gzip, "~> 0.4.2"},
      {:sweet_xml, "~> 0.7.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
