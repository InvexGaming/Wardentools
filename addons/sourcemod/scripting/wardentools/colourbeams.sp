/*
* Spawns beams (rings) on the ground
* Prefix: colourbeams_
*/

#if defined _wardentools_colourbeams_included
  #endinput
#endif
#define _wardentools_colourbeams_included

#include <wardentools>

#include "wardentools/colours.sp"

//Materials
static int g_BlackBeamSprite;
static int g_BeamSprite;
static int g_HaloSprite;

//OnMapStart
public void Colourbeams_OnMapStart()
{
  AddFileToDownloadsTable("materials/sprites/invex/black1.vmt");
  AddFileToDownloadsTable("materials/sprites/invex/black1.vtf");
  AddFileToDownloadsTable("materials/sprites/laserbeam.vmt");
  AddFileToDownloadsTable("materials/sprites/laserbeam.vtf");
  AddFileToDownloadsTable("materials/sprites/halo01.vmt");
  AddFileToDownloadsTable("materials/sprites/halo01.vtf");
  
  //Precache materials
  g_BlackBeamSprite = PrecacheModel("sprites/invex/black1.vmt", true);
  g_BeamSprite = PrecacheModel("sprites/laserbeam.vmt", true);
  g_HaloSprite = PrecacheModel("sprites/halo01.vmt", true);
}

public void Colourbeams_PlaceBeam(int client, float duration, float position[3])
{
  //Delegate to subfunction passing duration and position
  Colourbeams_PlaceBeam_Colour(duration, position, colours_current);
}

//Used to spawn Beams given a duration, position and colour
public void Colourbeams_PlaceBeam_Colour(float duration, float position[3], const int colour[4])
{
  int excessDurationCount = RoundToFloor(duration / 10.0);
  
  //Start timer to recreate beacon
  Handle beampack;
  CreateDataTimer(0.0, Colourbeams_ExcessBeamSpawner, beampack);
  WritePackCell(beampack, excessDurationCount);
  
  //Origin
  WritePackFloat(beampack, position[0]);
  WritePackFloat(beampack, position[1]);
  WritePackFloat(beampack, position[2]);
  
  //RGB Colour
  WritePackCell(beampack, colour[0]);
  WritePackCell(beampack, colour[1]);
  WritePackCell(beampack, colour[2]);
  WritePackCell(beampack, colour[3]);
}

//Used to spawn same beam every 10 second to avoid timer glitches for longer durations
public Action Colourbeams_ExcessBeamSpawner(Handle timer, Handle pack)
{
  ResetPack(pack);
  
  int excessDurationCount = ReadPackCell(pack);
  
  float hOrigin[3];
  hOrigin[0] = ReadPackFloat(pack);
  hOrigin[1] = ReadPackFloat(pack);
  hOrigin[2] = ReadPackFloat(pack);
  
  //RGB colour
  int beamColour[4];
  beamColour[0] = ReadPackCell(pack);
  beamColour[1] = ReadPackCell(pack);
  beamColour[2] = ReadPackCell(pack);
  beamColour[3] = ReadPackCell(pack);
  
  //Draw Beam
  //Set sprite to black or regular
  int beamSprite = g_BeamSprite;
  if ((beamColour[0] == colours_black[0]) &&
      (beamColour[1] == colours_black[1]) &&
      (beamColour[2] == colours_black[2]) &&
      (beamColour[3] == colours_black[3]))
    beamSprite = g_BlackBeamSprite;
    
  TE_SetupBeamRingPoint(hOrigin, 75.0, 75.5, beamSprite, g_HaloSprite, 0, 0, 10.0, 10.0, 0.0, beamColour, 0, 0);
  TE_SendToAll();
  
  //Restart next timer
  --excessDurationCount;
  
  if (excessDurationCount != 0) {
    Handle nextPack;
    CreateDataTimer(10.0, Colourbeams_ExcessBeamSpawner, nextPack);
    WritePackCell(nextPack, excessDurationCount);
    
    //Origin
    WritePackFloat(nextPack, hOrigin[0]);
    WritePackFloat(nextPack, hOrigin[1]);
    WritePackFloat(nextPack, hOrigin[2]);
    
    //RGB Colour
    WritePackCell(nextPack, beamColour[0]);
    WritePackCell(nextPack, beamColour[1]);
    WritePackCell(nextPack, beamColour[2]);
    WritePackCell(nextPack, beamColour[3]);
  }
}