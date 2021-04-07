FirstGameboyGame
================
Updating as proof for LIGO sys admin job posting Phillip Marr 2021

First attempt at teaching myself z80 assembler language, using memory mapped hardware, and creating a working game for the Nintendo Gameboy. I would ask anyone who takes a look at this to bare in mind that the learning of the z80 assembley langauge and creation of the game was done in under 30 days as a final project for my Microprocessors class (EE 3752 at Louisiana State University). 

The game is a very simple one; you move a sprite around and attempt to collect an object on screen. Once the object is collected, I randomly generate a new position for it. There are four obstacles circling the object that if touched result in a game over. Similarly, touching the edge of the screen is a game over. To add artificial difficulty, the controls for movement have been reversed (Eg. pressing up moves you down, etc.) and the sprite continually moves in last pressed direction in order to not give you time to think about what to press.
The scoreboard after the gameover is a static page that does not change, but lists the friends who helped test the game.

game.gb is the Gameboy file. It can be run with the BGB emulator (http://bgb.bircd.org/) for Windows. Mac users will have to search for a Gameboy or Gameboy Advanced emulator from http://www.emulator-zone.com/doc.php/mac/.

*.asm files contain all the code used. Some code, such as displaying a score were used from http://cratel.wichita.edu/cratel/ECE238Spr08. Any code that is my own is labeled as such in the .asm files.
Each .asm file contains its own documentation, and anything not explained can be read up on the above link.

*.inc files are include files that are used by the RGBDS compiler. They use directives that the z80 language didn't support back when it first came out, but make things like having separate .asm files possible.

If you wish to build the files into a .gb file, this page has the required software and steps: http://cratel.wichita.edu/cratel/ECE238Spr08/tutorials/GameBoyDevSetup.

Thanks to Shawn Farlow, my Microprocessors instructor, for giving me the push I needed to not only learn a new coding language, but to go beyond the project's basic requirements. This was a huge learning curve for me, but I am glad I was able to stick to it and build a Gameboy game in z80 assembler.

-Phillip Marr

All code is free to use, I just ask that you link to http://cratel.wichita.edu/cratel/ECE238Spr08 and this github. Thanks.
