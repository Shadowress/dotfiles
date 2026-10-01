# Extending the installer

Component-specific argument declarations live in matching `.sh` files in this
directory. Global component-selection arguments live in `components.sh`.

## Adding an argument

Add the declaration to the component's existing argument file, or create one
named after the component. Use kebab case for command-line names and
`ARG_COMPONENT_SETTING` for storage variables.

```bash
validate_example_mode_argument() {
    local value="$1"
    local provided="$2"

    if [[ "$provided" == "true" && "$PLATFORM" == "windows" ]]; then
        ARGUMENT_VALIDATION_ERROR="--example-mode is not supported on Windows."
        return 1
    fi
}

register_argument \
    "example-mode" \
    "ARG_EXAMPLE_MODE" \
    "enum" \
    "auto" \
    "auto|fast|safe" \
    "validate_example_mode_argument" \
    "Select the example component's operating mode."
```

`register_argument` fields must be supplied in this order:

| Position | Field | Example | Purpose |
|---:|---|---|---|
| 1 | CLI name | `example-mode` | Name used as `--example-mode` |
| 2 | Storage variable | `ARG_EXAMPLE_MODE` | Normalized value read by setup code |
| 3 | Type | `enum` | Selects generic parsing and validation |
| 4 | Default | `auto` | Value used when the option is omitted |
| 5 | Accepted values | `auto\|fast\|safe` | Pipe-delimited enum values; empty for other types |
| 6 | Validator | `validate_example_mode_argument` | Optional context-specific validation function |
| 7 | Description | `Select ...` | Text displayed by `--help` |
| 8 | Short alias | `e` | Optional one-character alias; otherwise empty |
| 9 | Help value label | `mode` | Optional placeholder displayed by `--help` |

Supported value types are:

| Type | Accepted input |
|---|---|
| `boolean` | A bare flag (treated as `true`), or `true`, `yes`, `1`, `on`, `false`, `no`, `0`, or `off` |
| `enum` | One of the pipe-delimited accepted values |
| `integer` | A positive, negative, or zero integer |
| `string` | Text preserved without type conversion |

Generic type and accepted-value checks belong in the central parser. Checks
that require system context or component-specific knowledge belong in the component's
validator. A validator receives the normalized value and either `true` or
`false` to indicate whether the user explicitly supplied the argument.
Defaults should normally remain valid on every platform.

Setup code reads only normalized `ARG_*` state and must not parse the command
line itself. Both bootstrap scripts forward the original argument list to
`install.sh` unchanged.

## Adding a component

Each independently selectable installation is a component. Add one using this
sequence:

1. Create its setup function in the appropriate setup directory.
2. Register all component metadata in one `register_component` call.
3. Add an argument file here only if the component needs its own options.
4. Optionally add it to `MINIMAL_COMPONENTS`.
5. Document any user-facing options in the root `README.md` installer-options
   table.

### 1. Add the setup function

| Availability | Setup file | Example |
|---|---|---|
| Every platform | `components/<component>.sh` | `components/example.sh` |
| One platform | `platforms/<platform>/<component>.sh` | `platforms/mac/example.sh` |
| Several platforms | One file under each supported platform | `platforms/linux/example.sh`, `platforms/wsl/example.sh` |

The file must define the setup function that will be registered, for example:

```bash
setup_example() {
    # Perform an idempotent setup.
}
```

### 2. Register the component

Add one line to the registry in `lib/components.sh`:

```bash
register_component "example" "Example Tool" "setup_example" "mac"
```

| Field | Example | Purpose |
|---|---|---|
| Component name | `example` | Value accepted by `--only`, `--include`, and `--skip` |
| Display name | `Example Tool` | Human-readable name used in help and status output |
| Setup function | `setup_example` | Function called when the component is selected |
| Platforms | `mac` | Environments where the component is available |

Platform metadata accepts these values:

| Value | Meaning |
|---|---|
| `all` | Available on every supported platform |
| `linux`, `mac`, `windows`, or `wsl` | Available only on that platform |
| Pipe-delimited values such as `linux\|wsl` | Available on several named platforms |

The registry drives valid-name checks, platform validation, component
selection, setup dispatch, and help output. Explicitly selecting an unavailable
platform-specific component fails before setup starts; unavailable components
in the default selection are omitted automatically.

### 3. Add component-specific arguments when needed

Create `components/arguments/example.sh` and use `register_argument` as described
above. Do not add an argument file when component selection is the only user
choice required.

### 4. Add it to the minimal installation when appropriate

Only components listed in `MINIMAL_COMPONENTS` are selected by `--minimal`:

```bash
MINIMAL_COMPONENTS=(
    "git"
    "gcm"
    "example"
)
```

Changing the minimal set does not require changes to the argument parser or
selection logic.
