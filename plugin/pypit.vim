" File: pypit.vim
" Author: OGINO Masanori <masanori.ogino@gmail.com>
" Original File: rbpit.vim
" Original Author: Koutarou Tanaka <from.kyushu.island@gmail.com>
" Last Change: 2009-12-23T02:26:24
" Version: 0.0.2
" License: BSD License

" Initialize {{{
if exists('g:loaded_pypit')
  finish
endif

let s:original_cpoptions = &cpoptions
set cpoptions&vim

if !exists('g:pypit_default')
  let g:pypit_default = 'vimrc'
endif
if !exists('g:pypit_autoload')
  let g:pypit_autoload = !0
endif

if !has('python')
  finish
endif
" }}}

" Python: import modules {{{
python << __END__
from pit import Pit
import re
import vim

def clean(D):
    """Clean dict."""
    if (len(D) == 2
        and 'username' in D
        and D['username'] == ''
        and 'password' in D
        and D['password'] == ''):
        return {}
    return D

def get(profname):
    """Get configurations."""
    return clean(Pit.get(profname))

def set(profname, data):
    """Set configurations."""
    Pit.set(profname, {'data': data})

def get_variable(name):
    """Evaluation."""
    value = vim.eval(name)
    value_type = int(vim.eval('type(%s)' % name))
    if value_type == 0:
        value = int(value)
    elif value_type == 3:
        for i in range(len(value)):
            value[i] = get_variable('%s[%s]' % (name, i))
    elif value_type == 4:
        for key in value:
            value[key] = get_variable('%s["%s"]' % (name, key))
    elif value_type == 5:
        value = float(value)
    return value
__END__
" }}}

function! PitGet(...)
  if a:0 == 0
    let l:profname = g:pypit_default
  elseif a:0 == 1 && len(a:1)
    let l:profname = a:1
  else
    throw 'too many arguments'
  endif
  let l:ret = {}
" Python: get pit config as JSON string {{{
python << __END__
config = get(vim.eval('l:profname'))
json_str = ''
for key, value in config.iteritems():
    if json_str == '':
        json_str += '{'
    else:
        json_str += ', '
    if isinstance(value, basestring):
        json_str += '"%s": "%s"' % (key, value)
    else:
        json_str += '"%s": %s' % (key, value)
if json_str != '':
    json_str += '}'
    vim.command('let l:ret = %s' % (json_str,))
__END__
" }}}
  if !exists('l:ret')
    let l:ret = {}
  endif
  return l:ret
endfunction

function! PitSet(...)
  if a:0 == 1 && len(a:1)
    let l:data = a:1
    let l:profname = g:pypit_default
  elseif a:0 == 2 && len(a:1) && len(a:2)
    let l:data = a:1
    let l:profname = a:2
  else
    throw 'too many or few arguments'
  endif
" Python: save to pit config {{{
python << __END__
profname = vim.eval('l:profname')
data = get_variable('l:data')
set(profname, data)
__END__
" }}}
endfunction

function! s:PitLoad(profname)
" Python: load pit config to global scope {{{
python << __END__
config = get(vim.eval('a:profname'))
for key, value in config.iteritems():
    key = 'g:%s' % (key,)
    if isinstance(value, basestring):
        vim.command('silent! unlet %(key)s | let %(key)s = "%(value)s"'
                    % {'key': key, 'value': value})
    else:
        vim.command('silent! unlet %(key)s | let %(key)s = %(value)s'
                    % {'key': key, 'value': value})
__END__
" }}}
endfunction

function! s:PitAdd(...)
  let l:profname = g:pypit_default
" Python: add variable to pit config {{{
python << __END__
profname = vim.eval('l:profname')
varcount = int(vim.eval('a:0'))
config = get(profname)
for i in range(1, varcount+1):
    varname = vim.eval('a:%d' % i)
    name = re.sub('[gsl]:', '', varname)
    value = get_variable(varname)
    config[name] = value
set(profname, config)
__END__
" }}}
endfunction

function! s:PitDel(...)
  let l:profname = g:pypit_default
" Python: delete variable from pit config {{{
python << __END__
profname = vim.eval('l:profname')
varcount = int(vim.eval('a:0'))
varnames = []
config = get(profname)
data = {}
for i in range(1, varcount+1):
    varname = vim.eval('a:%d' % i)
    name = re.sub('[gsl]:', '', varname)
    varnames.append(name)
for key in config:
    if key not in varnames:
        name = 'g:%s' % key
        value = get_variable(name)
        data[key] = value
set(profname, data)
__END__
" }}}
endfunction

function! s:PitShow(...)
  let l:profname = g:pypit_default
  if a:0 == 1 && len(a:1)
    let l:profname = a:1
  endif
  let l:config = PitGet(l:profname)
  echohl Title | echo l:profname | echohl None
  for l:key in keys(l:config)
    echohl LineNr | echo l:key | echohl None
    echo ' ' l:config[key]
  endfor
  silent! unlet l:config
endfunction

function! s:PitEdit(...)
  let l:profname = g:pypit_default
  if a:0 == 1 && len(a:1)
    let l:profname = a:1
  endif
  if len($EDITOR) == 0
    let $EDITOR = v:progname
  endif
  if executable('pit')
    exec '!pit set ' l:profname
  elseif executable('ppit')
    exec '!ppit set ' l:profname
  else
" Python: open text editor {{{
python << __END__
profname = vim.eval('l:profname')
Pit.set(profname, {})
__END__
" }}}
  endif
endfunction

function! s:PitSave(...)
  let l:profname = g:pypit_default
  if a:0 == 1 && len(a:1)
    let l:profname = a:1
  endif
" Python: save to pit config {{{
python << __END__
profname = vim.eval('l:profname')
config = get(profname)
data = {}
for key in config:
    name = 'g:%s' % key
    value = get_variable(name)
    data[key] = value
set(profname, data)
__END__
" }}}
endfunction

" Commands {{{
command! PitReload :call s:PitLoad(g:pypit_default)
command! -nargs=1 PitLoad :call s:PitLoad(<q-args>)
command! -nargs=* PitSave :call s:PitSave(<q-args>)
command! -nargs=* PitShow :call s:PitShow(<q-args>)
command! -nargs=* PitEdit :call s:PitEdit(<q-args>)
command! -nargs=+ -complete=var PitAdd :call s:PitAdd(<f-args>)
command! -nargs=+ -complete=var PitDel :call s:PitDel(<f-args>)
" }}}

if g:pypit_autoload
  call s:PitLoad(g:pypit_default)
endif

" Finalize {{{
let &cpoptions = s:original_cpoptions
let g:loaded_pypit = !0
" }}}

" vim:fdm=marker
