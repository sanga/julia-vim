" Facilities for moving around Julia blocks (e.g. if/end, function/end etc.)

let s:default_mappings = {
  \  "moveblock_n" : "]]",
  \  "moveblock_N" : "][",
  \  "moveblock_p" : "[[",
  \  "moveblock_P" : "[]",
  \
  \  "move_n" : "]j",
  \  "move_N" : "]J",
  \  "move_p" : "[j",
  \  "move_P" : "[J",
  \
  \  "select_a" : "aj",
  \  "select_i" : "ij",
  \  }

function! s:getmapchars(function)
  if exists("g:julia_blocks_mappings") && has_key(g:julia_blocks_mappings, a:function)
    return s:escape(g:julia_blocks_mappings[a:function])
  else
    return s:escape(s:default_mappings[a:function])
  endif
endfunction

let b:jlblk_mapped = {}

function! s:map_move(function, toend, backwards)
  let chars = s:getmapchars(a:function)
  if empty(chars)
    return
  endif
  let fn = "julia_blocks#" . a:function
  let lhs = "<buffer> <nowait> <silent> " . chars . " "
  let cnt = ":<C-U>let b:jlblk_count=v:count1"
  exe "nnoremap " . lhs . cnt
    \ . " <Bar> call " . fn . "()<CR>"
  exe "onoremap " . lhs . cnt
    \ . "<CR><Esc>:call julia_blocks#owrapper_move(v:operator, \"" . fn . "\", " . a:toend . ", " . a:backwards . ")<CR>"
  exe "xnoremap " . lhs . cnt
    \ . "<CR>gv<Esc>:call julia_blocks#vwrapper_move(\"" . fn . "\")<CR>"
  let b:jlblk_mapped[a:function] = 1
endfunction

function! julia_blocks#owrapper_move(oper, function, toend, backwards)
  let F = function(a:function)

  let save_redraw = &lazyredraw
  let save_select = &selection

  let restore_cmds = "\<Esc>"
    \ . ":let &l:selection = \"" . save_select . "\"\<CR>"
    \ . ":let &l:lazyredraw = " . save_redraw . "\<CR>"
    \ . ":\<BS>"

  setlocal lazyredraw

  let start_pos = getpos('.')
  let b:jlblk_abort_calls_esc = 0
  call F()
  let b:jlblk_abort_calls_esc = 1
  let end_pos = getpos('.')
  if start_pos == end_pos
    call feedkeys(restore_cmds)
  endif

  let &l:selection = "inclusive"
  if a:backwards || !a:toend
    let &l:selection = "exclusive"
  endif
  if a:toend && a:backwards
    let end_pos[2] += 1
  endif

  if s:compare_pos(start_pos, end_pos) > 0
    let [start_pos, end_pos] = [end_pos, start_pos]
  endif

  call setpos("'<", start_pos)
  call setpos("'>", end_pos)

  " NOTE: the 'c' operator behaves differently, for mysterious reasons. We
  "       simulate it with 'd' followed by 'i' instead
  call feedkeys("gv" . (a:oper == "c" ? "d" : a:oper) . restore_cmds . (a:oper == "c" ? "i" : ""))
endfunction

function! julia_blocks#vwrapper_move(function)
  let F = function(a:function)

  let s = getpos('.')
  let b1 = getpos("'<")
  let b2 = getpos("'>")

  let b = b1 == s ? b2 : b1
  call setpos('.', s)
  let b:jlblk_abort_calls_esc = 0
  call F()
  let b:jlblk_abort_calls_esc = 1
  let e = getpos('.')
  call setpos('.', b)
  exe "normal " . visualmode()
  call setpos('.', e)
endfunction

function! s:unmap(function)
  if !get(b:jlblk_mapped, a:function, 0)
    return
  endif
  let chars = s:getmapchars(a:function)
  if empty(chars)
    " shouldn't happen
    return
  endif
  let mapids = (a:function =~# "^move" ? ["n", "x", "o"] : ["x"])
  let fn = "julia_blocks#" . a:function
  let cmd = "<buffer> " . chars
  for m in mapids
    exe m . "unmap " . cmd
  endfor
  let b:jlblk_mapped[a:function] = 0
endfunction

function! s:escape(chars)
  let c = a:chars
  let c = substitute(c, '<', '<LT>', 'g')
  let c = substitute(c, '|', '<Bar>', 'g')
  return c
endfunction

function! s:map_select(function)
  let chars = s:getmapchars(a:function)
  if empty(chars)
    return
  endif
  let fn = "julia_blocks#" . a:function
  let lhs = "<buffer> <nowait> <silent> " . chars . " "
  let cnt = ":<C-U>let b:jlblk_inwrapper=1<CR>:let b:jlblk_count=max([v:prevcount,1])<CR>"
  exe "onoremap " . lhs . "<Esc>" . cnt
    \ . ":call julia_blocks#owrapper_select(v:operator, \"" . fn . "\")<CR>"
  exe "xnoremap " . lhs . cnt
    \ . ":call julia_blocks#vwrapper_select(\"" . fn . "\")<CR>"
  let b:jlblk_mapped[a:function] = 1
endfunction

function! julia_blocks#owrapper_select(oper, function) ", toend, backwards)
  let F = function(a:function)

  let save_redraw = &lazyredraw
  let save_select = &selection

  let restore_cmds = "\<Esc>"
    \ . ":let &l:selection = \"" . save_select . "\"\<CR>"
    \ . ":let &l:lazyredraw = " . save_redraw . "\<CR>"
    \ . ":\<BS>"

  setlocal lazyredraw

  let b:jlblk_abort_calls_esc = 0
  let retF = F()
  let b:jlblk_abort_calls_esc = 1
  if empty(retF)
    let b:jlblk_inwrapper = 0
    call feedkeys(restore_cmds)
    return
  end
  let [start_pos, end_pos] = retF

  if start_pos == end_pos
    call feedkeys(restore_cmds)
  endif

  let &l:selection = "inclusive"

  call setpos("'<", start_pos)
  call setpos("'>", end_pos)

  let b:jlblk_inwrapper = 0
  " NOTE: the 'c' operator behaves differently, for mysterious reasons. We
  "       simulate it with 'd' followed by 'i' instead
  call feedkeys("gv" . (a:oper == "c" ? "d" : a:oper) . restore_cmds . (a:oper == "c" ? "i" : ""))
endfunction

function! julia_blocks#vwrapper_select(function)
  let F = function(a:function)

  let b:jlblk_abort_calls_esc = 0
  let retF = F()
  let b:jlblk_abort_calls_esc = 1
  if empty(retF)
    let b:jlblk_inwrapper = 0
    return
  end
  let [start_pos, end_pos] = retF
  call setpos("'<", start_pos)
  call setpos("'>", end_pos)
  normal! gv
  let b:jlblk_inwrapper = 0
endfunction

let s:julia_blocks_functions = {
      \  "moveblock_N": [1, 0],
      \  "moveblock_n": [0, 0],
      \  "moveblock_p": [0, 1],
      \  "moveblock_P": [1, 1],
      \
      \  "move_N": [1, 0],
      \  "move_n": [0, 0],
      \  "move_p": [0, 1],
      \  "move_P": [1, 1],
      \
      \  "select_a": [],
      \  "select_i": [],
      \  }

function! julia_blocks#init_mappings()
  for f in keys(s:julia_blocks_functions)
    if f =~# "^move"
      let [te, bw] = s:julia_blocks_functions[f]
      call s:map_move(f, te, bw)
    else
      call s:map_select(f)
    endif
  endfor
  call julia_blocks#select_reset()
  augroup JuliaBlocks
    au!
    au InsertEnter *.jl call julia_blocks#select_reset()
    au CursorMoved *.jl call s:cursor_moved()
  augroup END

  " we would need some autocmd event associated with exiting from
  " visual mode, but there isn't any, so we resort to this crude
  " hack
  vnoremap <buffer><silent><unique> <Esc> <Esc>:call julia_blocks#select_reset()<CR>
endfunction

function! julia_blocks#remove_mappings()
  for f in keys(s:julia_blocks_functions)
    call s:unmap(f)
  endfor
  unlet! b:jlblk_save_pos b:jlblk_count b:jlblk_abort_calls_esc
  unlet! b:jlblk_inwrapper b:jlblk_did_select b:jlblk_doing_select
  unlet! b:jlblk_last_start_pos b:jlblk_last_end_pos b:jlblk_last_mode
  augroup JuliaBlocks
    au!
  augroup END
  augroup! JuliaBlocks
  let md = maparg("<Esc>", "x", 0, 1)
  if !empty(md) && md["buffer"]
    vunmap <buffer> <Esc>
  endif
endfunction

function! s:abort()
  call setpos('.', b:jlblk_save_pos)
  if get(b:, "jlblk_abort_calls_esc", 1)
    call feedkeys("\<Esc>")
  endif
  return 0
endfunction

function! s:set_mark_tick(...)
  call setpos("''", b:jlblk_save_pos)
endfunction

function! s:get_save_pos(...)
  if !exists("b:jlblk_save_pos") || (a:0 == 0) || (a:0 > 0 && a:1)
    let b:jlblk_save_pos = getpos('.')
  endif
endfunction

function! s:on_end()
  return getline('.')[col('.')-1] =~# '\k' && expand("<cword>") =~# b:julia_end_keywords
endfunction

function! s:on_begin()
  return getline('.')[col('.')-1] =~# '\k' && expand("<cword>") =~# b:julia_begin_keywords
endfunction

function! s:cycle_until_end()
  let pos = getpos('.')
  while !s:on_end()
    normal %
    let c = 0
    if getpos('.') == pos || c > 1000
      " shouldn't happen, but let's avoid infinite loops anyway
      return 0
    endif
    let c += 1
  endwhile
  return 1
endfunction

function! s:moveto_block_delim(toend, backwards, ...)
  let pattern = a:toend ? b:julia_end_keywords : b:julia_begin_keywords
  let flags = a:backwards ? 'Wb' : 'W'
  let cnt = a:0 > 0 ? a:1 : b:jlblk_count
  let ret = 0
  for c in range(cnt)
    if a:toend && a:backwards && s:on_end()
      normal! bh
    endif
    while 1
      let searchret = search(pattern, flags)
      if !searchret
	return ret
      endif
      exe "let skip = " . b:match_skip
      if !skip
	let ret = 1
	break
      endif
    endwhile
  endfor
  return ret
endfunction

function! s:compare_pos(pos1, pos2)
  if a:pos1[1] < a:pos2[1]
    return -1
  elseif a:pos1[1] > a:pos2[1]
    return 1
  elseif a:pos1[2] < a:pos2[2]
    return -1
  elseif a:pos1[2] > a:pos2[2]
    return 1
  else
    return 0
  endif
endfunction

function! julia_blocks#move_N()
  call s:get_save_pos()

  let ret = s:moveto_block_delim(1, 0)
  if !ret
    return s:abort()
  endif

  normal! e
  call s:set_mark_tick()

  return 1
endfunction

function! julia_blocks#move_n()
  call s:get_save_pos()

  let ret = s:moveto_block_delim(0, 0)
  if !ret
    return s:abort()
  endif

  call s:set_mark_tick()

  return 1
endfunction

function! julia_blocks#move_p()
  call s:get_save_pos()

  let ret = s:moveto_block_delim(0, 1)
  if !ret
    return s:abort()
  endif

  call s:set_mark_tick()

  return 1
endfunction

function! julia_blocks#move_P()
  call s:get_save_pos()

  let ret = s:moveto_block_delim(1, 1)
  if !ret
    return s:abort()
  endif

  normal! e
  call s:set_mark_tick()

  return 1
endfunction

function! s:moveto_currentblock_end()
  let flags = 'W'
  if s:on_end()
    let flags .= 'c'
    " NOTE: using "normal! lb" fails at the end of the file (?!)
    normal! l
    normal! b
  endif

  let ret = searchpair(b:julia_begin_keywords, '', b:julia_end_keywords, flags, b:match_skip)
  if ret <= 0
    return s:abort()
  endif

  normal! e
  return 1
endfunction

function! julia_blocks#moveblock_N()
  call s:get_save_pos()

  let ret = 0
  for c in range(b:jlblk_count)
    let last_seen_pos = getpos('.')
    if s:on_end()
      normal! hel
      let save_pos = getpos('.')
      let ret_start = s:moveto_block_delim(0, 0, 1)
      let start1_pos = ret_start ? getpos('.') : [0,0,0,0]
      call setpos('.', save_pos)
      if s:on_end()
	normal! h
      endif
      let ret_end = s:moveto_block_delim(1, 0, 1)
      let end1_pos = ret_end ? getpos('.')  : [0,0,0,0]

      if ret_start && (!ret_end || s:compare_pos(start1_pos, end1_pos) < 0)
	call setpos('.', start1_pos)
      else
	call setpos('.', save_pos)
      endif
    endif

    let moveret = s:moveto_currentblock_end()
    if !moveret && c == 0
      let moveret = s:moveto_block_delim(0, 0, 1) && s:cycle_until_end()
      if moveret
        normal! e
      endif
    endif
    if !moveret
      call setpos('.', last_seen_pos)
      break
    endif

    let ret = 1
  endfor
  if !ret
    return s:abort()
  endif

  call s:set_mark_tick()

  return 1
endfunction

function! julia_blocks#moveblock_n()
  call s:get_save_pos()

  let ret = 0
  for c in range(b:jlblk_count)
    let last_seen_pos = getpos('.')

    call s:moveto_currentblock_end()
    if s:moveto_block_delim(0, 0, 1)
      let ret = 1
    else
      call setpos('.', last_seen_pos)
      break
    endif
  endfor

  if !ret
    return s:abort()
  endif

  call s:set_mark_tick()

  return 1
endfunction

function! julia_blocks#moveblock_p()
  call s:get_save_pos()

  let ret = 0
  for c in range(b:jlblk_count)
    let last_seen_pos = getpos('.')
    if s:on_begin()
      normal! lbh
      if s:on_end()
	normal! l
      endif
      let save_pos = getpos('.')
      let ret_start = s:moveto_block_delim(0, 1, 1)
      let start1_pos = ret_start ? getpos('.') : [0,0,0,0]
      call setpos('.', save_pos)
      let ret_end = s:moveto_block_delim(1, 1, 1)
      let end1_pos = ret_end ? getpos('.') : [0,0,0,0]

      if ret_end && (!ret_start || s:compare_pos(start1_pos, end1_pos) < 0)
	call setpos('.', end1_pos)
      else
	call setpos('.', save_pos)
      endif
    endif

    let moveret = s:moveto_currentblock_end()
    if !moveret && c == 0
      let moveret = s:moveto_block_delim(1, 1, 1)
    endif
    if !moveret
      call setpos('.', last_seen_pos)
      break
    endif

    normal %
    let ret = 1
  endfor
  if !ret
    return s:abort()
  endif

  call s:set_mark_tick()

  return 1
endfunction

function! julia_blocks#moveblock_P()
  call s:get_save_pos()

  let ret = 0
  for c in range(b:jlblk_count)
    let last_seen_pos = getpos('.')

    call s:moveto_currentblock_end()
    if s:on_end()
      normal %
    endif

    if s:moveto_block_delim(1, 1, 1)
      normal! he
      let ret = 1
    else
      call setpos('.', last_seen_pos)
    endif
  endfor

  if !ret
    return s:abort()
  endif

  call s:set_mark_tick()

  return 1
endfunction


" Block text objects

function! s:find_block(current_mode)

  let flags = 'W'

  if b:jlblk_did_select
    call setpos('.', b:jlblk_last_start_pos)
    if !s:cycle_until_end()
      return s:abort()
    endif
    if !(a:current_mode[0] == 'a' && a:current_mode == b:jlblk_last_mode)
      let flags .= 'c'
    endif
  elseif s:on_end()
    let flags .= 'c'
    " NOTE: using "normal! lb" fails at the end of the file (?!)
    normal! l
    normal! b
  endif
  let searchret = searchpair(b:julia_begin_keywords, '', b:julia_end_keywords, flags, b:match_skip)
  if searchret <= 0
    if !b:jlblk_did_select
      return s:abort()
    else
     call setpos('.', b:jlblk_last_end_pos)
    endif
  endif

  let end_pos = getpos('.')
  " Jump to match
  normal %
  let start_pos = getpos('.')

  let b:jlblk_last_start_pos = copy(start_pos)
  let b:jlblk_last_end_pos = copy(end_pos)

  return [start_pos, end_pos]
endfunction

function! s:repeated_find(ai_mode)
  let repeat = b:jlblk_count + (a:ai_mode == 'i' && v:count1 > 1 ? 1 : 0)
  for c in range(repeat)
    let current_mode = (c < repeat - 1 ? 'a' : a:ai_mode)
    let ret_find_block = s:find_block(current_mode)
    if empty(ret_find_block)
      return 0
    endif
    let [start_pos, end_pos] = ret_find_block
    call setpos('.', end_pos)
    let b:jlblk_last_mode = current_mode
    if c < repeat - 1
      let b:jlblk_doing_select = 0
      let b:jlblk_did_select = 1
    endif
  endfor
  return [start_pos, end_pos]
endfunction

function! julia_blocks#select_a(...)
  call s:get_save_pos(!b:jlblk_did_select)
  let current_pos = getpos('.')
  let ret_find_block = s:repeated_find('a')
  if empty(ret_find_block)
    return 0
  endif
  let [start_pos, end_pos] = ret_find_block

  call setpos('.', end_pos)
  normal! e
  let end_pos = getpos('.')

  let b:jlblk_doing_select = 1

  " CursorMove is only triggered if end_pos
  " end_pos is different than the staring position;
  " so when starting from the 'd' in 'end' we need to
  " force it
  if current_pos == end_pos
    call s:cursor_moved(1)
  endif

  call s:set_mark_tick()
  return [start_pos, end_pos]
endfunction

function! julia_blocks#select_i()
  call s:get_save_pos(!b:jlblk_did_select)
  let current_pos = getpos('.')
  let ret_find_block = s:repeated_find('i')
  if empty(ret_find_block)
    return 0
  endif
  let [start_pos, end_pos] = ret_find_block

  if end_pos[1] <= start_pos[1]+1
    return s:abort()
  endif

  call setpos('.', end_pos)

  let b:jlblk_doing_select = 1

  let start_pos[1] += 1
  call setpos('.', start_pos)
  normal! ^
  let start_pos = getpos('.')
  let end_pos[1] -= 1
  let end_pos[2] = len(getline(end_pos[1]))

  " CursorMove is only triggered if end_pos
  " end_pos is different than the staring position;
  " so when starting from the 'd' in 'end' we need to
  " force it
  if current_pos == end_pos
    call s:cursor_moved(1)
  endif

  call s:set_mark_tick()
  return [start_pos, end_pos]
endfunction

function julia_blocks#select_reset()
  let b:jlblk_did_select = 0
  let b:jlblk_doing_select = 0
  let b:jlblk_inwrapper = 0
  let b:jlblk_last_mode = ""
endfunction

function! s:cursor_moved(...)
  if b:jlblk_inwrapper && !(a:0 > 0 && a:1)
    return
  endif
  let b:jlblk_did_select = b:jlblk_doing_select
  let b:jlblk_doing_select = 0
endfunction
