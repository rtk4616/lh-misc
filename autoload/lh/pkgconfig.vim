"=============================================================================
" File:         autoload/lh/pkgconfig.vim                         {{{1
" Author:       Luc Hermitte <EMAIL:luc {dot} hermitte {at} gmail {dot} com>
"		<URL:http://github.com/LucHermitte/lh-misc>
" License:      GPL v3 with Exception
"               <URL:http://github.com/LucHermitte/lh-misc/blob/master/License.md>
" Version:      0.0.1.
let s:k_version = 001
" Created:      12th Sep 2018
" Last Update:  14th Sep 2018
"------------------------------------------------------------------------
" Description:
"       Support functions for plugin/pkgconfig
"
"------------------------------------------------------------------------
" History:      «history»
" TODO:
" * Support lhv#project variable, e.g. p:$CXXFLAGS
" * Support Fortran...
" * Check if we can use CPPFLAGS for `-I` ?
" }}}1
"=============================================================================

let s:cpo_save=&cpo
set cpo&vim
"------------------------------------------------------------------------
" ## Misc Functions     {{{1
" # Version {{{2
function! lh#pkgconfig#version()
  return s:k_version
endfunction

" # Debug   {{{2
let s:verbose = get(s:, 'verbose', 0)
function! lh#pkgconfig#verbose(...)
  if a:0 > 0 | let s:verbose = a:1 | endif
  return s:verbose
endfunction

function! s:Log(expr, ...) abort
  call call('lh#log#this',[a:expr]+a:000)
endfunction

function! s:Verbose(expr, ...) abort
  if s:verbose
    call call('s:Log',[a:expr]+a:000)
  endif
endfunction

function! lh#pkgconfig#debug(expr) abort
  return eval(a:expr)
endfunction


"------------------------------------------------------------------------
" ## Exported functions {{{1
" Function: lh#pkgconfig#cmd(command, ...) {{{3
let s:k_executable = 'pkg-config'

if 1
  let s:loaded_pkgs = {}
  let s:pkg_infos   = {}
  let $CFLAGS = ''
  let $CXXFLAGS = ''
  let $LDFLAGS = ''
  let $LDLIBS = ''
endif
let s:loaded_pkgs = get(s:, 'loaded_pkgs', {})
let s:pkg_infos   = get(s:, 'pkg_infos', {})

function! lh#pkgconfig#cmd(command, ...) abort
  call lh#assert#value(lh#os#system_detected()).eq('unix')
  if a:0 == 0
    return
  elseif a:command == 'load'
    call lh#pkgconfig#_load(a:000)
  elseif a:command == 'unload'
    call lh#pkgconfig#_unload(a:000)
  else
    throw "pkg-config: Unexpected command: ".a:command
  endif
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1

function! s:add_to_var(var, value) abort
  exe 'let '.a:var.' .= " ".a:value'
  call s:Verbose('%1 = %2', a:var, eval(a:var))
endfunction

function! s:remove_from_var(var, value) abort
  if empty(a:value) | return | endif
  exe 'let old_value = '.a:var
  let where = stridx(old_value, a:value)
  call lh#assert#value(where).is_ge(0)
  let offset =  where > 0 && old_value[where-1] == ' '
  let value = strpart(old_value, 0, where-offset)
        \   . strpart(old_value, where+strlen(a:value))
  exe 'let '.a:var.' = value'
  call s:Verbose('%1 = %2', a:var, value)
endfunction

" Function: lh#pkgconfig#_load(libs) {{{3
function! lh#pkgconfig#_load(libs) abort
  call s:Verbose('Load pkg-config info for: %1', a:libs)
  if lh#os#is_a_cygwin_shell()
    let cleanup = lh#on#exit()
          \.restore('shellxquote')
    set shellxquote=(
  endif
  try
    for lib in a:libs
      " Register the lib
      if has_key(s:loaded_pkgs, lib)
        let s:loaded_pkgs[lib] += 1
      else
        let cmd = [s:k_executable, '--cflags',          lib, ';']
              \ + [s:k_executable, '--libs-only-L',     lib, ';']
              \ + [s:k_executable, '--libs-only-l',     lib, ';']
              \ + [s:k_executable, '--libs-only-other', lib, ';']
        let info = lh#os#system(join(cmd, ' '))
        if v:shell_error
          throw "pkg-config: ".info
        endif
        let info_list = split(info, "\n", 1)
        call s:Verbose("Information: %1", info_list)

        let s:pkg_infos[lib] = {
              \ 'cflags' : info_list[0],
              \ 'ldlibs' : info_list[2],
              \ 'ldflags': lh#string#trim(info_list[1].' '.info_list[3])
              \ }
        call s:add_to_var('$CFLAGS',   s:pkg_infos[lib].cflags)
        call s:add_to_var('$CXXFLAGS', s:pkg_infos[lib].cflags)
        call s:add_to_var('$LDFLAGS',  s:pkg_infos[lib].ldflags)
        call s:add_to_var('$LDLIBS',   s:pkg_infos[lib].ldlibs)
        let s:loaded_pkgs[lib]  = 1
      endif
      call s:Verbose('%1(%3) -> %2', lib, s:pkg_infos[lib], s:loaded_pkgs[lib])
    endfor
  finally
    if exists('cleanup')
      call cleanup.finalize()
    endif
  endtry
endfunction

" Function: lh#pkgconfig#_unload(libs) {{{3
function! lh#pkgconfig#_unload(libs) abort
  call s:Verbose('Unload pkg-config info for: %1', a:libs)
  for lib in a:libs
    if get(s:loaded_pkgs, lib, 0) == 0
      call lh#common#warning_msg('No pkg-config variables loaded for '.lib)
    elseif s:loaded_pkgs[lib] == 1
      call s:Verbose("Do unload pkg-config variables for %1", lib)
      call s:remove_from_var('$CFLAGS',   s:pkg_infos[lib].cflags)
      call s:remove_from_var('$CXXFLAGS', s:pkg_infos[lib].cflags)
      call s:remove_from_var('$LDFLAGS',  s:pkg_infos[lib].ldflags)
      call s:remove_from_var('$LDLIBS',   s:pkg_infos[lib].ldlibs)
      unlet s:loaded_pkgs[lib]
    else
      let s:loaded_pkgs[lib] -= 1
    endif
  endfor
endfunction

" Function: lh#pkgconfig#_complete(ArgLead, CmdLine, CursorPos) {{{2
function! lh#pkgconfig#_complete(ArgLead, CmdLine, CursorPos) abort
  let [pos, tokens; dummy] = lh#command#analyse_args(a:ArgLead, a:CmdLine, a:CursorPos)

  if 1 == pos
    let res = ['load', 'unload']
    " there is non need to support all options of pkg-config. Indeed,
    " they can be called from the command line.
    " What interrests us, is to be able to set $C(XX)FLAGS, $LDFLAGS and
    " $LDLIBS from Vim before running |:make|
    "" let res = [ '--version', '--modversion',
    ""       \ '--atleast-pkgconfig-version=VERSION', '--libs', '--static',
    ""       \ '--short-errors', '--libs-only-l', '--libs-only-other',
    ""       \ '--libs-only-L', '--cflags', '--cflags-only-I',
    ""       \ '--cflags-only-other', '--variable=NAME',
    ""       \ '--define-variable=NAME=VALUE', '--exists', '--print-variables',
    ""       \ '--uninstalled', '--atleast-version=VERSION',
    ""       \ '--exact-version=VERSION', '--max-version=VERSION', '--list-all',
    ""       \ '--debug', '--print-errors', '--silence-errors',
    ""       \ '--errors-to-stdout', '--print-provides', '--print-requires',
    ""       \ '--print-requires-private', '--validate', '--define-prefix',
    ""       \ '--dont-define-prefix', '--prefix-variable=PREFIX',
    ""       \ ]
  else
    " TODO: find where _completion_loader is installed..
    " Or glob into $PKG_CONFIG_PATH + /usr/lib/pkgconfig...
    if lh#command#can_use_bash_completion()
      let res = lh#command#matching_bash_completion('pkg-config', a:ArgLead)
    else
      let res = split(lh#os#system(s:k_executable. ' --list-all'), "\n")
      call map(res, 'matchstr(v:val, "\\v^\\S+")')
    endif
  endif
  call filter(res, 'v:val =~ "^".a:ArgLead')
  return res
endfunction

"------------------------------------------------------------------------
" }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
