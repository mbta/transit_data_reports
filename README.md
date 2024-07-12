# transit_data_reports

## Introduction

This repository provides a common place to store [Livebook](https://livebook.dev)-based reports for Transit Data. 

## Setup

1. Install Livebook, either through Poetry or the desktop app
2. Create (or rename the default) a Hub to contain all of the MBTA / Transit Data reports
3. Add the report(s) you wish to run to a Hub
4. Add secret(s) to the Hub

## Secrets

Livebook uses secrets to keep sensitive data out of code. These essentially take the place of environment variables (and in fact ultimately get accessed as environment variables in code). For right now, it is exclusively for AWS access, but if more services need to be accessed, this is where the API keys should be stored. The naming convention follows the pattern of `SOME_SECRET_NAME` resulting in an environment variable `LB_SOME_SECRET_NAME` in the code context.

To register and use a secret within Livebook:
1. Go to your Hub. There should be a link to it in the left sidebar.
2. Add the secret under the Secrets section on that page.
3. Return to the notebook that needs access to the secret and click the 🔒 icon in the left sidebar.\
   Toggle on the secret to give the notebook access.
4. You can now read the secret in any code cell within that notebook, with:
   ```ex
   System.get_env("LB_#{name_you_gave_the_secret_in_hub}")
   ```

1. AWS_ACCESS_KEY_ID
   1. This can be any key that has appropriate permissions for the report. By default, your access keys are stored at `~/.aws/credentials`. 
2. AWS_SECRET_ACCESS_KEY
   1. Same as above

## Development

Some of the logic for these reports is maintained in a mix project, as a sort of library.[^1]

If your report has any logic that:
- is CPU-intensive, or
- needs to be reused by other reports, or
- is just a lot of lines of code and would benefit from a proper code editor,

consider putting that logic in lib/ instead of in-lining it within your notebook.

[^1]: This is because of a few reasons:
   - Keeping all of the logic as inline code cells within a notebook quickly becomes unwieldy;
   - The Livebook code cell editor is somewhat feature-limited;
   - Some notebooks have shared logic;
   - Logic defined in modules gets compiled and has at least an order-of-magnitude better performance than anonymous fns defined in code cells.\
      From the "Welcome to Livebook" notebook:
      > However, it is important to remember that all code outside of
      > a module in Erlang or Elixir is *evaluated*, and therefore
      > executes much slower than code defined inside modules, which
      > are *compiled*.
