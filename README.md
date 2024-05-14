# transit_data_reports

## Introduction

This repository provides a common place to store [Livebook](https://livebook.dev)-based reports for Transit Data. 

## Setup

1. Install Livebook, either through Poetry or the desktop app
2. Create (or rename the default) a Hub to contain all of the MBTA / Transit Data reports
3. Add the report(s) you wish to run to a Hub
4. Add secret(s) to the Hub

## Secrets

Livebook uses secrets to keep sensitive data out of code. These essentially take the place of environment variables (and in fact ultimately get accessed as environment variables in code). For right now, it is exclusively for AWS access, but if more services need to be accessed, this is where the API keys should be stored. The naming convention follows the pattern of `SOME_SECRET_NAME` resulting in an environment variable `LIVEBOOK_SOME_SECRET_NAME` in the code context. 

1. AWS_ACCESS_KEY_ID
   1. This can be any key that has appropriate permissions for the report. By default, your access keys are stored at `~/.aws/credentials`. 
2. AWS_SECRET_ACCESS_KEY
   1. Same as above
