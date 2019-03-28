#!/bin/bash

# A modified version of https://github.com/schwern/svn2git/ but in Bash Script beacause.. why not!!!

# If your running this script on mac os x you must install gnu-getopts execute:
#   brew install gnu-getopt
#   export PATH="/usr/local/opt/gnu-getopt/bin:$PATH"
PREFIX="svn/"

help () {
    echo -e "\n"
    echo "Usage: ./svn2git.sh [OPTIONS] <SVN_URL>"
    echo -e "\n"
    echo -e "\tSVN_URL: Specifies the subversion url where your current project lives."
    echo -e "\n"
    echo "OPTIONS"
    echo -e "\n"
    echo -e "\t--verbose: Prints debug messages and git commands being executed"
    echo -e "\t--notrunk: Indicates git that there is no trunk path in the current repository"
    echo -e "\t--nobranches: Indicates git that there is no branches path in the current repository"
    echo -e "\t--notags: Indicates git that there is no tags path in the current repository"
    echo -e "\t--logrev: Tries to identify the initial revision for the current SVN URL"
    echo -e "\t--trunk: The path to trunk in svn repository, <trunk> by default"
    echo -e "\t--branches: The path to branches in svn repository, <branches> by default"
    echo -e "\t--tags: The path to tags in svn repository, <tags> by default"
    echo -e "\t--authors: The path to authors file"
    echo -e "\t--no-metadata: Tells git-svn to process repository with no metadata"
    echo .e "\t--unstoppable: Force the execution of this script in spite of local branch/tag errors"
    echo -e "\t--help: Information about the script"
    echo -e "\n"
    exit 0
}

main(){
    check_env;
    clone;
    fix_elements;
    run git checkout master
    gc
    post
    success "Process finished, listing elements in the repository"
    echo "BRANCHES:"
    run git branch -l
    echo "TAGS:"
    run git tag -l
}

die () {
    echo -e "\x1B[91m \xE2\x9D\x8C $* \x1B[0m" >&2
    exit 1;
}

log () {
    printf "$*\n"
}

success () {
    echo -e "\x1B[32m \xE2\x9C\x94 $* \x1B[0m\n"
}

debug () {
    [ $verbose = true ] && echo -e "$*\n"
}

warn () {
    echo -e "\x1B[93m ! $*\x1B[0m\n"
}

run (){
    debug "running [$@]"
    eval "$@"
    [ $? != 0 ] && die "Error in last command:\n\t[$*]"
    return 0;
}

#This function name was provided by Lyz
run_and_maybe_die (){
    debug "running [$@]"
    eval "$@"
    [ $? != 0 ] && [ false = $do_not_stop_me_now ] &&  die "Error in last command:\n\t[$*]"
    return 0;
}

clone(){
    if [ -z "$SVN_URL" ]; then
        help
    fi
    log "Initializing git repo"
    git_init_cmd="git svn init --prefix=$PREFIX $no_metadata"
    git_opts=(trunk branches tags)
    git_init_opts=()
    for opt in "${git_opts[@]}"; do
        no_option=no_$opt
        if [ ${!no_option} = false ]; then
            git_init_opts+="--$opt=${!opt} "
        fi
    done
    debug "git svn layout ${git_init_opts[@]}"
    run $git_init_cmd ${git_init_opts[@]} $SVN_URL

    revision=""
    if [ true = "$log_revision" ]; then
        warn "Looking for first revision $SVN_URL"
        rev=($(svn log -r 1:HEAD --limit 1 $SVN_URL | grep -a -e "^r" | awk {'print $1}'))
        if [ -z "$rev" ]; then
            die "Initial revision not found for $SVN_URL"
        else
            revision="-$rev:HEAD"
            success "Successfully found initial revision [$rev] for $SVN_URL"
        fi
    fi
    [ ! -z "$authors" ] && authors="--authors-file=$authors"
    git_fetch_cmd="git svn $revision $authors fetch"
    run $git_fetch_cmd
    success "Successfully cloned $SVN_URL into local git repo $PWD"
}

fix_elements(){
    git_svn_remotes=($(git branch -r))
    for remote_branch in "${git_svn_remotes[@]}"; do
        case $remote_branch in
            $prefix*$trunk)
                log "Trunk [$remote_branch] found"
                fix_trunk $remote_branch
            ;;
            $prefix*$tags/*)
                log "Tag [$remote_branch] found"
                tag $remote_branch
            ;;
            *)
                log "Branch [$remote_branch] found"
                branch $remote_branch
            ;;
        esac
    done
}

tag(){
    remote_branch=$1
    log Tagging $remote_branch 
    run "git" "show-ref" $remote_branch
    if [ $? != 0 ]; then
        warn "Not a valid branch reference: $remote_branch. Skipping"
        return;
    fi
    IFS=/ read -ra branch_elements <<<"$remote_branch"
    tag_name="${branch_elements[@]: -1:1}"
    
    run "git" "checkout"  $remote_branch
    run_and_maybe_die "git" "tag" $tag_name
    success $remote_branch tagged as $tag_name!!
}

branch(){
    remote_branch=$1
    debug Local branching $remote_branch 
    run "git" "show-ref" $remote_branch
    if [ $? != 0 ]; then
        warn "Not a valid branch reference: $remote_branch. Skipping"
        return;
    fi

    IFS=/ read -ra branch_elements <<<"$remote_branch"
    branch_name="${branch_elements[@]: -1:1}"
    
    run "git" "checkout"  $remote_branch
    run_and_maybe_die "git" "checkout" "-b" $branch_name
    success $remote_branch locally branched as $branch_name!!
}

fix_trunk(){
    remote_branch=$1
    log Mastering trunk $remote_branch 
    run "git" "show-ref" $remote_branch
    if [ $? != 0 ]; then
        warn "Not a valid branch reference: $remote_branch. Skipping"
        return;
    fi    
    run "git" "checkout" $remote_branch
    run "git" "branch" "-D" "master"
    run "git" "checkout" "-f" "-b" "master"
    success $remote_branch mastered!!
    
}

post() {
    run "git" "svn" "show-ignore" ">" ".gitignore"
    run "git" "add" ".gitignore"
    run "git" "commit" "-m" "\"Ignored elements added\""
    success "Ignored elements added to .gitignore"
} 

check_env (){
    $(git --version);
    if [ $? -ne 0 ]; then
        die "You should install git first!\n"
    fi
}

gc() {
    debug "Realizando tareas de limpieza"
    run git gc --quiet;
    if [ $? -eq 0 ]; then
        success "Successfully cleaned the repository\n"
    fi
}

# Execution begins
# Configure options for this script
OPTIONS=`getopt -o t --long help,verbose,unstoppable,logrev,nobranches,notrunk,notags,no-metadata\
,trunk:,branches:,tags:,authors: -- "$@"`

[ $? -eq 0 ] || {
    echo "Incorrect options provided"
    exit 1
}
eval set -- $OPTIONS

verbose=false
log_revision=false
trunk="trunk"
branches="branches"
tags="tags"
no_trunk=false
no_branches=false
no_tags=false
help=false
authors=
tag_prefix=
no_metadata=
do_not_stop_me_now=false
while true; do
    case "$1" in
        --verbose ) verbose=true; shift ;;
        --notrunk ) no_trunk=true; shift ;;
        --nobranches ) no_branches=true; shift ;;
        --notags ) no_tags=true; shift ;;
        --logrev ) log_revision=true; shift ;;
        --trunk ) trunk="$2"; shift 2 ;;
        --branches ) branches="$2"; shift 2 ;;
        --tags ) tags="$2"; shift 2 ;;
        --authors) authors="$2"; shift 2 ;;
        --no-metadata) no_metadata="--no-metadata"; shift ;;
        --unstoppable) do_not_stop_me_now=true; shift ;; # 'cause I'm having a good time
        --help) help=true; shift ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done

SVN_URL=$1
# Run
if [ $help = true ] || [ $# = 0 ]; then
    help
fi
main
