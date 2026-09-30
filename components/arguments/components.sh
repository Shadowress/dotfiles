register_argument \
    "help" \
    "ARG_HELP" \
    "boolean" \
    "false" \
    "" \
    "" \
    "Show this help and exit." \
    "h"

register_argument \
    "include" \
    "ARG_INCLUDE" \
    "string" \
    "" \
    "" \
    "" \
    "Add comma-separated components to --minimal." \
    "" \
    "components"

register_argument \
    "minimal" \
    "ARG_MINIMAL" \
    "boolean" \
    "false" \
    "" \
    "" \
    "Install the centrally defined minimal component set."

register_argument \
    "only" \
    "ARG_ONLY" \
    "string" \
    "" \
    "" \
    "" \
    "Install only the specified comma-separated components." \
    "" \
    "components"

register_argument \
    "skip" \
    "ARG_SKIP" \
    "string" \
    "" \
    "" \
    "" \
    "Remove comma-separated components from the selection." \
    "" \
    "components"
