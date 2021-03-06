# bartlett

A simple Jenkins command line client to serve your needs.

#### Motivation

We live on the command line, and anything that can help us stay there longer is
a boon to productivity. While the Jenkins web interface is nice for many, it is
a distracting context switch for us.

Our goal for this tool is to replicate many of the workflows that we use
day-to-day through the web interface in a single, easy to use command line
client. Additionally, many of the existing clients are either not under active
development or do not satisfy the below requirements for a CLI Jenkins client.

##### Why not just use the Jenkins CLI jar?

A few reasons:

  1. `bartlett`'s focus is on translating workflows from the web ui to the
  command line.
      * It is _not_ meant to be a replacement for the Jenkins CLI jar, where the
      primary focus is on remotely administrating a Jenkins instance
  2. `bartlett`'s output is primarly JSON, which means that it can be piped
  into tools like [jq][jq-page] and scripted programmatically
  3. Profile support to alleviate the tedium of working with multiple Jenkins
  instances
      * Similar in spirit to AWS CLI profiles
  4. Some Jenkins instances are not configured to allow JNLP access
      * `bartlett` instead talks to Jenkins over its REST API
  5. We want a tool that can be installed as a static binary

##### And why not just use curl?

You could, but you'll end up tying a lot more in the long run. `bartlett`'s
support for profiles and CSRF crumb generation means that authentication and
Jenkins instance resolution are done for you at invocation. You also don't
have to worry about exposing your password since `bartlett` doesn't accept it
as a configuration or command line option (only requested at runtime with
hidden input).

## Supported Platforms

`bartlett` is currently built and tested for the following platforms:

|Platform|Version|
|--------|-------|
|Mac OSX | El Capitan and above |

If you would like to assist in building and testing versions for more platforms
please check
[the issue tracker for your platform of choice](https://github.com/Nike-Inc/bartlett/issues?q=is%3Aissue+is%3Aopen+label%3A%22Platform+Support%22).

## Installation

### from Homebrew

Please track the following issue for Homebrew support:
https://github.com/Nike-Inc/bartlett/issues/4

### from Source

Make sure you have [Stack][stack-install] installed before you begin.

Change directory to where you store your development projects:

```
git clone https://github.com/Nike-Inc/bartlett.git
cd bartlett && stack build && stack install
```

## Getting Help

At this time the best way to contact us is
[by filing an issue](https://github.com/Nike-Inc/bartlett/issues/new). We hope
to expand our level of support to other mediums in the near future.

## Usage

##### A note about protocols

Bartlett will honor any protocol explicitly passed on the command line or via
configuration. However, if no protocol is provided then Bartlett will attempt
to contact your Jenkins instance via HTTPS. It is _strongly_ recommended that
you talk to your Jenkins instance via HTTPS when possible.

### Getting Help at the Command Line

You can get a list of available options with the `-h` flag:

```
$ bartlett -h
bartlett - the Jenkins command-line tool to serve your needs.

Usage: bartlett [-u|--username USERNAME] [-j|--jenkins JENKINS_INSTANCE]
                [-p|--profile PROFILE_NAME] COMMAND

Available options:
  -h,--help                Show this help text
  -u,--username USERNAME   The user to authenticate with
  -j,--jenkins JENKINS_INSTANCE
                           The Jenkins instance to interact with
  -p,--profile PROFILE_NAME
                           The profile to source values from

Available commands:
  info                     Get information on the given job
  build                    Trigger a build for the given job
  config                   Manage XML configurations for jobs

Copyright (c) Nike, Inc. 2016
```

### Querying Existing Jobs

You can query for basic information about a given job by providing the path
from the root of your Jenkins instance to the desired job.

For example, if my job exists at
`https://my.jenkins-instance.com/job/TEST/job/testJob/`, then I can query
this job's information like so:

```
bartlett --username my_user --jenkins https://my.jenkins-instance.com info TEST/testJob
```

You can also pass this output directly to the [jq][jq-page] tool to query data
even further:

```
$ bartlett --username my_user \
    --jenkins https://my.jenkins-instance.com info TEST/testJob \
    | jq '.jobs | .[] | .name'
"00_my-first-job"
"01_my-second-job"
"02_my-third-job"
```

You can even pass in multiple jobs at once by separating each job path with
a space:

```
$ bartlett -u my_user -j https://my.jenkins-instance.com \
  info FOO BAR | jq '.jobs | .[] | .name'
Enter password:
"foojob-one"
"foojob-two"
"barjob-one"
"barjob-two"
```

You may find after a while that entering your password for each invocation
becomes tedious. For your convenience, Bartlett can cache user passwords on a
per profile basis. See the "Configuring Profiles" section for more information.

### Triggering Job Builds

You can build parameterized and normal jobs by using the `build` sub-command.

For example, if my job exists at
`https://my.jenkins-instance.com/job/~my_user/job/test`, then I can trigger its
build like so:

```
$ bartlett --username my_user \
    --jenkins https://my.jenkins-instance.com build /~my_user/test
Enter password:
{
    "status": "201"
}
```

Or, if I have a job with parameters, I can pass these parameters in using the
`-p` flag.

```
$ bartlett --username my_user --jenkins https://my.jenkins-instance.com \
    build /~my_user/test --options FOO=bar,BAZ=quux
Enter password:
{
    "status": "201"
}
```

### Managing Job Configurations

You can manage the XML job configurations for any job on your Jenkins instance
by using the `config` sub-command.

To get the current configuration for your job run the `config` sub-command
against the path to your job:

```xml
bartlett --username my_user --jenkins https://my.jenkins.com \
  config /path/to/my/job
Enter password:
<?xml version="1.0" encoding="UTF-8"?><project>
  <description/>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>echo "lolwut there"</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
```

We can pipe the output of the previous command to a file, make some
modifications, and then update the configuration with the following command:

```
bartlett --username my_user --jenkins https://my.jenkins.com \
  config /path/to/my/job -f ./config.xml
Enter password:
{
    "statusMessage": "OK",
    "statusCode": 200
}
```

### Configuring Profiles

You may store configuration values for many different Jenkins instances. First
create a bartlett configuration file:

```bash
touch ~/.bartlett.cfg && $EDITOR ~/.bartlett.cfg
```

By default, values will attempt to be sourced from the `default` configuration
block.

```
# The default profile
default {
  jenkins_instance = "https://my.jenkins-instance.com"
  username = "my_user"
}

# Additional profile
dank_profile {
  jenkins_instance = "https://dank.jenkins-instance.com"
  username = "wewlad"
}
```

You can then invoke Bartlett without providing user or Jenkins options:

```bash
bartlett info /  # Uses the default profile from above
bartlett --profile dank_profile info /  # Source a different profile
```

If a value is provided on the command line _AND_ configured in a profile, then
the value provided on the command line will take precedence.

#### Supported Configuration Values

The following values are supported by the latest version of Bartlett:

| Value | Default | Description|
|-------|---------|------------|
| `username` | None | The username to authenticate against Jenkins with. |
| `jenkins_instance` | None | The Jenkins instance to interact with. |
| `store_password` | false | If true, securely store the user's password on next invocation. |

##### A note on password storage

Bartlett will attempt to store user credentials using OSX's Keychain service.
By default, passwords **are not** stored and must explictly enable storage
using the above configuration options _for each profile_.

## Development

Make sure you have [Stack][stack-install] installed before you begin.

Then build the project:

```bash
stack build
```

Or alternatively start a REPL to test things out interactively:

```bash
stack ghci
```

#### Running Tests on File Change

When actively working on a feature we'll typically run the following to get
automatic feedback as we write code:

```bash
stack build --test --coverage --haddock --copy-bins --file-watch
```

Or run the make target:

```
make watch
```

To exit out of this loop type `quit` (instead of C-c).

#### Building a Static Binary

Surprise, more Stack options!

```bash
stack build --force-dirty --haddock --copy-bins
```

Or use the make target:

```bash
make package-bin
```

### What's in a name?

[Leslie Bartlett][bartlett-wiki] was a famous butler who founded the London
School of British Butlers.

[bartlett-wiki]: https://en.wikipedia.org/wiki/Leslie_Bartlett
[stack-install]: https://docs.haskellstack.org/en/stable/README/
[jq-page]: https://stedolan.github.io/jq/
[homebrew-install]: http://brew.sh/
