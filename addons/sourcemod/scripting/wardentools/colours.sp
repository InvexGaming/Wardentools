/*
* Selects colours that can be used by other modules
* Prefix: colours_
*/

#if defined _wardentools_colours_included
  #endinput
#endif
#define _wardentools_colours_included

#include <wardentools>

//Defines
#define COLOURS_DEFAULT 0
#define COLOURS_RED 1
#define COLOURS_GREEN 2
#define COLOURS_BLUE 3
#define COLOURS_PURPLE 4
#define COLOURS_YELLOW 5
#define COLOURS_CYAN 6
#define COLOURS_PINK 7
#define COLOURS_ORANGE 8
#define COLOURS_WHITE 9
#define COLOURS_BLACK 10

//Proper Globals
int colours_full[4] = {255, 255, 255, 255};
int colours_red[4] = {255, 0, 0, 200};
int colours_green[4] = {0, 255, 0, 200};
int colours_blue[4] = {0, 0, 255, 200};
int colours_purple[4] = {128, 112, 214, 200};
int colours_yellow[4] = {255, 255, 0, 200};
int colours_cyan[4] = {0, 255, 255, 200};
int colours_pink[4] = {255, 105, 180, 200};
int colours_orange[4] = {255, 140, 0, 200};
int colours_white[4] = {254, 254, 254, 200};
int colours_black[4] = {1, 1, 1, 200};

int colours_current[4] = {255, 0, 0, 200}; //red is default
int colours_currentColourCode = COLOURS_RED;

//Getters/Setters

//Set Colour
public void Colours_SetCurrentColour(const int newColour[4])
{
  colours_current[0] = newColour[0];
  colours_current[1] = newColour[1];
  colours_current[2] = newColour[2];
  colours_current[3] = newColour[3];
}

//Colour code to colours
public void Colours_GetColourFromColourCode(int colourCode, int colour[4])
{
  if (colourCode == COLOURS_RED) {
    colour[0] = colours_red[0];
    colour[1] = colours_red[1];
    colour[2] = colours_red[2];
    colour[3] = colours_red[3];
  }
  else if (colourCode == COLOURS_GREEN) {
    colour[0] = colours_green[0];
    colour[1] = colours_green[1];
    colour[2] = colours_green[2];
    colour[3] = colours_green[3];
  }
  else if (colourCode == COLOURS_BLUE) {
    colour[0] = colours_blue[0];
    colour[1] = colours_blue[1];
    colour[2] = colours_blue[2];
    colour[3] = colours_blue[3];
  }
  else if (colourCode == COLOURS_PURPLE) {
    colour[0] = colours_purple[0];
    colour[1] = colours_purple[1];
    colour[2] = colours_purple[2];
    colour[3] = colours_purple[3];
  }
  else if (colourCode == COLOURS_YELLOW) {
    colour[0] = colours_yellow[0];
    colour[1] = colours_yellow[1];
    colour[2] = colours_yellow[2];
    colour[3] = colours_yellow[3];
  }
  else if (colourCode == COLOURS_CYAN) {
    colour[0] = colours_cyan[0];
    colour[1] = colours_cyan[1];
    colour[2] = colours_cyan[2];
    colour[3] = colours_cyan[3];
  }
  else if (colourCode == COLOURS_PINK) {
    colour[0] = colours_pink[0];
    colour[1] = colours_pink[1];
    colour[2] = colours_pink[2];
    colour[3] = colours_pink[3];
  }
  else if (colourCode == COLOURS_ORANGE) {
    colour[0] = colours_orange[0];
    colour[1] = colours_orange[1];
    colour[2] = colours_orange[2];
    colour[3] = colours_orange[3];
  }
  else if (colourCode == COLOURS_WHITE) {
    colour[0] = colours_white[0];
    colour[1] = colours_white[1];
    colour[2] = colours_white[2];
    colour[3] = colours_white[3];
  }
  else if (colourCode == COLOURS_BLACK) {
    colour[0] = colours_black[0];
    colour[1] = colours_black[1];
    colour[2] = colours_black[2];
    colour[3] = colours_black[3];
  }
  else { //includes COLOURS_DEFAULT
    colour[0] = colours_full[0];
    colour[1] = colours_full[1];
    colour[2] = colours_full[2];
    colour[3] = colours_full[3];
  }
}