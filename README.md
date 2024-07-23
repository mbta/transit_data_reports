# transit_data_reports

## Introduction

This repository provides a common place to store
[Livebook](https://livebook.dev)-based reports for Transit Data.

## Setup

1. Clone or download this repository.
2. Install Livebook, either through Poetry or the desktop app. (Desktop app
   recommended)
3. Create a Hub (or rename the default) to contain all of the MBTA / Transit
   Data reports.
4. Add the report(s) you wish to run to a Hub.\
   Make sure to open them _in situ_—they need to be located in the reports/
   directory for certain code to work properly.
5. Add secret(s) to the Hub.

## Secrets

Livebook uses secrets to keep sensitive data out of code. These essentially take
the place of environment variables (and in fact ultimately get accessed as
environment variables in code). For right now, it is exclusively for AWS access,
but if more services need to be accessed, this is where the API keys should be
stored. The naming convention follows the pattern of `SOME_SECRET_NAME`
resulting in an environment variable `LB_SOME_SECRET_NAME` in the code context.

You will most likely need to add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
secrets at minimum.

To register and use a secret within Livebook:
1. Go to your Hub. There should be a link to it in the left sidebar.
2. Add the secret under the Secrets section on that page.
3. Return to the notebook that needs access to the secret and click the 🔒 icon
   in the left sidebar.\
   Toggle on the secret to give the notebook access.
4. You can now read the secret in any code cell within that notebook, with:
   ```ex
   System.get_env("LB_#{name_you_gave_the_secret_in_hub}")
   ```

## Development

Some of the logic for these reports is maintained in a mix project, as a sort of
library.

If your report has any logic that:
- is CPU-intensive[^1], or
- needs to be reused by other reports, or
- is just a lot of lines of code and would benefit from a proper code editor,

consider putting that logic in lib/ instead of a code cell within your
notebook.

When starting a new notebook file, paste the following into its setup cell to
pull in the TransitData library:
```ex
# Assuming this notebook is saved in /reports...
project_dir = __DIR__ |> Path.join("..") |> Path.expand()

Mix.install(
  [
    {:kino, "~> 0.12.0"},
    {:transit_data, path: project_dir},
    # transit_data needs a timezone DB for some date-related logic.
    {:tz, "~> 0.26.5"},
    # Put any additional libraries needed by this notebook here.
  ],
  config: [
    elixir: [time_zone_database: Tz.TimeZoneDatabase],
    # (Assuming your notebook needs to access data in S3)
    ex_aws: [
      access_key_id: System.get_env("LB_AWS_ACCESS_KEY_ID"),
      secret_access_key: System.get_env("LB_AWS_SECRET_ACCESS_KEY"),
      region: "us-east-1"
    ]
  ]
)
```

Note that if you have a notebook open in Livebook and make changes to the
library code, you'll need to re-run the notebook's setup cell to pick up your
changes.

[^1]: This is because code inside modules gets compiled and has at least an
    order-of-magnitude performance boost over anonymous fns defined in evaluated
    code cells.\
      From the "Welcome to Livebook" notebook:
      > However, it is important to remember that all code outside of a module
      > in Erlang or Elixir is *evaluated*, and therefore executes much slower
      > than code defined inside modules, which are *compiled*.
