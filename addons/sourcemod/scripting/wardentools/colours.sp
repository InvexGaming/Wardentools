/*
* Selects colours that can be used by other modules
* Prefix: Colours_
*/

#if defined _wardentools_colours_included
  #endinput
#endif
#define _wardentools_colours_included

#include <wardentools>

//Defines
enum Colour
{
  Colour_Default,
  Colour_Red,
  Colour_Green,
  Colour_Blue,
  Colour_Purple,
  Colour_Yellow,
  Colour_Cyan,
  Colour_Pink,
  Colour_Orange,
  Colour_White,
  Colour_Black
};

//Proper Globals
int g_Colours_Full[] = {255, 255, 255, 255};
int g_Colours_Red[] = {255, 0, 0, 200};
int g_Colours_Green[] = {0, 255, 0, 200};
int g_Colours_Blue[] = {0, 0, 255, 200};
int g_Colours_Purple[] = {128, 112, 214, 200};
int g_Colours_Yellow[] = {255, 255, 0, 200};
int g_Colours_Cyan[] = {0, 255, 255, 200};
int g_Colours_Pink[] = {255, 105, 180, 200};
int g_Colours_Orange[] = {255, 140, 0, 200};
int g_Colours_White[] = {254, 254, 254, 200};
int g_Colours_Black[] = {1, 1, 1, 200};

int g_Colours_Current[] = {255, 0, 0, 200}; //red is default
Colour g_Colours_CurrentColourCode = Colour_Red;

//Getters/Setters

//Set Colour
public void Colours_SetCurrentColour(const int newColour[4])
{
  g_Colours_Current[0] = newColour[0];
  g_Colours_Current[1] = newColour[1];
  g_Colours_Current[2] = newColour[2];
  g_Colours_Current[3] = newColour[3];
}

//Colour code to colours
public void Colours_GetColourFromColourCode(Colour colourCode, int colour[4])
{
  if (colourCode == Colour_Red) {
    colour[0] = g_Colours_Red[0];
    colour[1] = g_Colours_Red[1];
    colour[2] = g_Colours_Red[2];
    colour[3] = g_Colours_Red[3];
  }
  else if (colourCode == Colour_Green) {
    colour[0] = g_Colours_Green[0];
    colour[1] = g_Colours_Green[1];
    colour[2] = g_Colours_Green[2];
    colour[3] = g_Colours_Green[3];
  }
  else if (colourCode == Colour_Blue) {
    colour[0] = g_Colours_Blue[0];
    colour[1] = g_Colours_Blue[1];
    colour[2] = g_Colours_Blue[2];
    colour[3] = g_Colours_Blue[3];
  }
  else if (colourCode == Colour_Purple) {
    colour[0] = g_Colours_Purple[0];
    colour[1] = g_Colours_Purple[1];
    colour[2] = g_Colours_Purple[2];
    colour[3] = g_Colours_Purple[3];
  }
  else if (colourCode == Colour_Yellow) {
    colour[0] = g_Colours_Yellow[0];
    colour[1] = g_Colours_Yellow[1];
    colour[2] = g_Colours_Yellow[2];
    colour[3] = g_Colours_Yellow[3];
  }
  else if (colourCode == Colour_Cyan) {
    colour[0] = g_Colours_Cyan[0];
    colour[1] = g_Colours_Cyan[1];
    colour[2] = g_Colours_Cyan[2];
    colour[3] = g_Colours_Cyan[3];
  }
  else if (colourCode == Colour_Pink) {
    colour[0] = g_Colours_Pink[0];
    colour[1] = g_Colours_Pink[1];
    colour[2] = g_Colours_Pink[2];
    colour[3] = g_Colours_Pink[3];
  }
  else if (colourCode == Colour_Orange) {
    colour[0] = g_Colours_Orange[0];
    colour[1] = g_Colours_Orange[1];
    colour[2] = g_Colours_Orange[2];
    colour[3] = g_Colours_Orange[3];
  }
  else if (colourCode == Colour_White) {
    colour[0] = g_Colours_White[0];
    colour[1] = g_Colours_White[1];
    colour[2] = g_Colours_White[2];
    colour[3] = g_Colours_White[3];
  }
  else if (colourCode == Colour_Black) {
    colour[0] = g_Colours_Black[0];
    colour[1] = g_Colours_Black[1];
    colour[2] = g_Colours_Black[2];
    colour[3] = g_Colours_Black[3];
  }
  else { //includes COLOURS_DEFAULT
    colour[0] = g_Colours_Full[0];
    colour[1] = g_Colours_Full[1];
    colour[2] = g_Colours_Full[2];
    colour[3] = g_Colours_Full[3];
  }
}