\ Copyright (c) 2003 Scott Long <scottl@FreeBSD.org>
\ Copyright (c) 2003 Aleksander Fafula <alex@fafula.com>
\ Copyright (c) 2006-2015 Devin Teske <dteske@FreeBSD.org>
\ All rights reserved.
\ Copyright 2018 Nexenta Systems, Inc. All rights reserved.
\
\ Redistribution and use in source and binary forms, with or without
\ modification, are permitted provided that the following conditions
\ are met:
\ 1. Redistributions of source code must retain the above copyright
\    notice, this list of conditions and the following disclaimer.
\ 2. Redistributions in binary form must reproduce the above copyright
\    notice, this list of conditions and the following disclaimer in the
\    documentation and/or other materials provided with the distribution.
\ 
\ THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
\ ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
\ IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
\ ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
\ FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
\ DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
\ OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
\ HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
\ LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
\ OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
\ SUCH DAMAGE.
\ 
\ $FreeBSD$

39 logoX ! 1 logoY ! \ Initialize logo placement defaults

: logo+ ( x y c-addr/u -- x y' )
	2swap 2dup at-xy 2swap \ position the cursor
	[char] @ escc! \ replace @ with Esc
	type \ print to the screen
	1+ \ increase y for next time we're called
;

: logo ( x y -- ) \ color nexenta logo
      
       s" /boot/nexenta.png" fb-putimage if 2drop exit then
        
       s"                                     " logo+ 
       s"                                     " logo+ 
       s"                                     " logo+     
       s"       `         ````                " logo+ 
       s"      `:/`    `-/+ooooo++/-.         " logo+ 
       s"    `/o+`   `/oooooooooooooo+:`      " logo+ 
       s"   .+oo/   `+oooooooooooooooooo:`    " logo+ 
       s"  .+ooo+   .oooooooooooooooooooo+`   " logo+ 
       s"  +ooooo:   :oooooooooo+//::/+ooo+`  " logo+ 
       s" .ooooooo+.  `-:///:-.`       `-/o:  " logo+ 
       s" .ooooooooo/-         .:///:.    -/  " logo+ 
       s" `+oooooooooo+-     `+ooooooo/    .  " logo+ 
       s"  -oooooooooooo/   `+ooooooooo-      " logo+ 
       s"   :oooooooooooo-  -oooooooooo:      " logo+ 
       s"    .+ooooooooo+.  +oooooooooo-      " logo+ 
       s"      .:+ooooo/.  -oooooooooo/       " logo+ 
       s"         ``.`    -+ooooooooo/`       " logo+ 
       s"               ./ooooooooo/.         " logo+ 
       s"         .-::/ooooooooo+:`           " logo+ 
       s"           `.-::::::-.`              " logo+ 

	2drop
;
