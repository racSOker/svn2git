#!/bin/bash

# A modified version of https://github.com/schwern/svn2git/ but in Bash Script beacause.. why not!!!

PREFIX="svn/"

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
    echo -e "\x1B[93m$*\n\x1B[0"
}

run (){
    debug "running [$@]"
    eval "$@"
    [ $? != 0 ] && die "Error in last command:\n\t[$*]"
    return 0;
}
main(){
    check_env;
    clone;
    fix_elements;
    run git checkout master
    success "Process finished, showing elements in the repository"
    run git branch -l
    run git tag -l

}

clone(){
    
    if [ -z "$SVN_URL" ]; then
        die "usage: $0 [options] <SVN_URL>";
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
    
    [ ! -z "$authors" ] && authors="--authors-file=$authors"
    git_fetch_cmd="git svn $authors fetch"
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
    run "git" "tag" $tag_name
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
    run "git" "checkout" "-b" $branch_name
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

check_env (){
    $(git --version);
    if [ $? -ne 0 ]; then
        die "You should install git first!\n";
    fi
}

# Execution begins
# Configure options for this script
OPTIONS=`getopt -o t --long help,verbose,logrev,no-branches,notrunk,notags,no-metadata\
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
authors=
tag_prefix=
no_metadata=
while true; do
    case "$1" in
        --verbose ) verbose=true; shift ;;
        --notrunk ) no_trunk=true; shift ;;
        --no-branches ) no_branches=true; shift ;;
        --notags ) no_tags=true; shift ;;
        --logrev ) log_revision=true; shift ;;
        --trunk ) trunk="$2"; shift 2 ;;
        --branches ) branches="$2"; shift 2 ;;
        --tags ) tags="$2"; shift 2 ;;
        --authors) authors="$2"; shift 2 ;;
        --no-metadata) no_metadata="--no-metadata"; shift ;;
        --help) help; shift ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done

SVN_URL=$1
# Run
main
