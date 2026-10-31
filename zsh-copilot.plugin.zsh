#!/usr/bin/env zsh

# Default key binding
(( ! ${+ZSH_COPILOT_KEY} )) &&
    typeset -g ZSH_COPILOT_KEY='^z'

# Configuration options
(( ! ${+ZSH_COPILOT_SEND_CONTEXT} )) &&
    typeset -g ZSH_COPILOT_SEND_CONTEXT=true

(( ! ${+ZSH_COPILOT_DEBUG} )) &&
    typeset -g ZSH_COPILOT_DEBUG=false

# System prompt
if [[ -z "$ZSH_COPILOT_SYSTEM_PROMPT" ]]; then
read -r -d '' ZSH_COPILOT_SYSTEM_PROMPT <<- EOM
  You will be given the raw input of a shell command. 
  Your task is to either complete the command or provide a new command that you think the user is trying to type. 
  If you return a completely new command for the user, prefix is with an equal sign (=). 
  If you return a completion for the user's command, prefix it with a plus sign (+). 
  MAKE SURE TO ONLY INCLUDE THE REST OF THE COMPLETION!!! 
  Do not write any leading or trailing characters except if required for the completion to work. 

  Only respond with either a completion or a new command, not both. 
  Your response may only start with either a plus sign or an equal sign.
  Your response MAY NOT start with both! This means that your response IS NOT ALLOWED to start with '+=' or '=+'.

  Your response MAY NOT contain any newlines!
  Do NOT add any additional text, comments, or explanations to your response.
  Do not ask for more information, you won't receive it. 

  Your response will be run in the user's shell. 
  Make sure input is escaped correctly if needed so. 
  Your input should be able to run without any modifications to it.
  DO NOT INTERACT WITH THE USER IN NATURAL LANGUAGE! If you do, you will be banned from the system. 
  Note that the double quote sign is escaped. Keep this in mind when you create quotes. 
  Here are two examples: 
    * User input: 'list files in current directory'; Your response: '=ls' (ls is the builtin command for listing files)
    * User input: 'cd /tm'; Your response: '+p' (/tmp is the standard temp folder on linux and mac).
EOM
fi

if [[ "$ZSH_COPILOT_DEBUG" == 'true' ]]; then
    touch /tmp/zsh-copilot.log
fi

# All endpoints use the OpenAI-compatible Chat Completions protocol.
function _fetch_suggestions() {
    local data response message response_code
    local -a headers

    if [[ "$ZSH_COPILOT_ENDPOINT" != http://* && "$ZSH_COPILOT_ENDPOINT" != https://* ]] || [[ -z "$ZSH_COPILOT_MODEL" ]]; then
        print -r -- "Set ZSH_COPILOT_ENDPOINT (full http(s) Chat Completions URL) and ZSH_COPILOT_MODEL." > /tmp/.zsh_copilot_error
        return 1
    fi

    headers=(-H "Content-Type: application/json")
    [[ -n "$ZSH_COPILOT_API_KEY" ]] && headers+=(-H "Authorization: Bearer $ZSH_COPILOT_API_KEY")
    data=$(jq -cn --arg model "$ZSH_COPILOT_MODEL" --arg system "$full_prompt" --arg input "$input" \
        '{model: $model, stream: false, messages: [
          {role: "system", content: $system}, {role: "user", content: $input}]}') || return 1

    response=$(curl --silent --show-error --fail \
        --connect-timeout 10 --max-time "${ZSH_COPILOT_TIMEOUT:-60}" \
        "$ZSH_COPILOT_ENDPOINT" "${headers[@]}" -d "$data")
    response_code=$?

    if [[ "$ZSH_COPILOT_DEBUG" == true ]]; then
        jq -cn --arg date "$(date)" --arg endpoint "$ZSH_COPILOT_ENDPOINT" \
            --arg input "$input" --arg response "$response" --arg code "$response_code" \
            '{date: $date, endpoint: $endpoint, input: $input, response: $response, response_code: $code}' \
            >> /tmp/zsh-copilot.log
    fi

    if (( response_code != 0 )); then
        print -r -- "Error fetching suggestions from $ZSH_COPILOT_ENDPOINT (curl exit $response_code). Check endpoint, credentials and model." > /tmp/.zsh_copilot_error
        return 1
    fi

    message=$(print -r -- "$response" | jq -er \
        'select(.error == null) | .choices[0].message.content | select(type == "string" and length > 0)' 2>/dev/null)
    if (( $? != 0 )) || [[ "$message" == *$'\n'* || ( "$message" != '+'* && "$message" != '='* ) || "$message" == '+='* || "$message" == '=+'* ]]; then
        print -r -- "Invalid or empty suggestion from $ZSH_COPILOT_ENDPOINT. Check model support and API response (enable ZSH_COPILOT_DEBUG for details)." > /tmp/.zsh_copilot_error
        return 1
    fi

    print -r -- "$message" > /tmp/zsh_copilot_suggestion || return 1
}


function _show_loading_animation() {
    local pid=$1
    local interval=0.1
    local animation_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=1

    cleanup() {
      kill $pid
      echo -ne "\e[?25h"
    }
    trap cleanup SIGINT
    
    while kill -0 $pid 2>/dev/null; do
        # Display current animation frame
        zle -R "${animation_chars[i]}"

        # Update index, make sure it starts at 1
        i=$(( (i + 1) % ${#animation_chars[@]} ))

        if [[ $i -eq 0 ]]; then
            i=1
        fi
        
        sleep $interval
    done

    echo -ne "\e[?25h"
    trap - SIGINT
}

function _suggest_ai() {
    #### Prepare environment

    local context_info=""
    if [[ "$ZSH_COPILOT_SEND_CONTEXT" == 'true' ]]; then
        local system

        if [[ "$OSTYPE" == "darwin"* ]]; then
            system="Your system is ${$(sw_vers | xargs | sed 's/ /./g')}."
        else 
            system="Your system is ${$(cat /etc/*-release | xargs | sed 's/ /,/g')}."
        fi

        context_info="Context: You are user $(whoami) with id $(id) in directory $(pwd). 
            Your shell is $(echo $SHELL) and your terminal is $(echo $TERM) running on $(uname -a).
            $system"
    fi

    ##### Get input
    rm -f /tmp/zsh_copilot_suggestion /tmp/.zsh_copilot_error
    local input="${BUFFER:0:$CURSOR}"
    input=${input//$'\n'/;}

    _zsh_autosuggest_clear

    local full_prompt="$ZSH_COPILOT_SYSTEM_PROMPT $context_info"

    ##### Fetch message
    read < <(_fetch_suggestions & echo $!)
    local pid=$REPLY

    _show_loading_animation $pid
    local response_code=$?

    if [[ "$ZSH_COPILOT_DEBUG" == 'true' ]]; then
        echo "{\"date\":\"$(date)\",\"log\":\"Fetched message\",\"input\":\"$input\",\"response\":\"$response_code\",\"message\":\"$message\"}" >> /tmp/zsh-copilot.log
    fi

    if [[ ! -f /tmp/zsh_copilot_suggestion ]]; then
        _zsh_autosuggest_clear
        echo $(cat /tmp/.zsh_copilot_error 2>/dev/null || echo "No suggestion available at this time. Please try again later.")
        return 1
    fi

    local message=$(cat /tmp/zsh_copilot_suggestion)

    ##### Process response

    local first_char=${message:0:1}
    local suggestion=${message:1:${#message}}
    
    if [[ "$ZSH_COPILOT_DEBUG" == 'true' ]]; then
        echo "{\"date\":\"$(date)\",\"log\":\"Suggestion extracted.\",\"input\":\"$input\",\"response\":\"$response\",\"first_char\":\"$first_char\",\"suggestion\":\"$suggestion\",\"data\":\"$data\"}" >> /tmp/zsh-copilot.log
    fi

    ##### And now, let's actually show the suggestion to the user!

    if [[ "$first_char" == '=' ]]; then
        # Reset user input
        BUFFER=""
        CURSOR=0

        zle -U "$suggestion"
    elif [[ "$first_char" == '+' ]]; then
        _zsh_autosuggest_suggest "$suggestion"
    fi
}

function zsh-copilot() {
    echo "ZSH Copilot is now active. Press $ZSH_COPILOT_KEY to get suggestions."
    echo ""
    echo "Configurations:"
    echo "    - ZSH_COPILOT_KEY: Key to press to get suggestions (default: ^z, value: $ZSH_COPILOT_KEY)."
    echo "    - ZSH_COPILOT_SEND_CONTEXT: If \`true\`, zsh-copilot will send context information (whoami, shell, pwd, etc.) to the AI model (default: true, value: $ZSH_COPILOT_SEND_CONTEXT)."
    echo "    - ZSH_COPILOT_ENDPOINT: Full OpenAI-compatible Chat Completions URL (value: $ZSH_COPILOT_ENDPOINT)."
    echo "    - ZSH_COPILOT_MODEL: Model name (value: $ZSH_COPILOT_MODEL)."
    echo "    - ZSH_COPILOT_API_KEY: API key (optional for local endpoints)."
    echo "    - ZSH_COPILOT_TIMEOUT: Request timeout in seconds (default: 60, value: ${ZSH_COPILOT_TIMEOUT:-60})."
    echo "    - ZSH_COPILOT_SYSTEM_PROMPT: System prompt to use for the AI model (uses a built-in prompt by default)."
}

zle -N _suggest_ai
bindkey "$ZSH_COPILOT_KEY" _suggest_ai

