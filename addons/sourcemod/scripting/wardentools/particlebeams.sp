/*
* Spawns beams (particles) on the ground
* Prefix: ParticleBeams_
*/

#if defined _wardentools_particlebeams_included
  #endinput
#endif
#define _wardentools_particlebeams_included

#include <wardentools>

//Defines
#define MAX_PARTICLES 256
#define DEFAULT_PARTICLEBEAMS_STYLE 0
#define PARTICLE_PCF_FILE "particles/invexbeams1.pcf"

enum CustomParticles
{
  String:szParticleName[PLATFORM_MAX_PATH],
  String:szEffectName[PLATFORM_MAX_PATH],
  String:szNiceName[PLATFORM_MAX_PATH],
  iCacheID,
}

//Global
int ParticleBeams_List[MAX_PARTICLES][CustomParticles];

//Statics
static int s_NumParticleStyles = 0;
static int s_CurParticleStyle = 0;

//OnPluginStart
public void ParticleBeams_OnPluginStart()
{
  ArrayList effectList = new ArrayList(64);
  ArrayList niceNameList = new ArrayList(128);
  
  //Add the selectable particle effects
  effectList.PushString("beam_rainbow");
  niceNameList.PushString("Rainbow | Rainbow 1");
  
  effectList.PushString("beam_rainbow2");
  niceNameList.PushString("Rainbow | Rainbow 2");
  
  effectList.PushString("beam_ring10");
  niceNameList.PushString("Rainbow | Rainbow 3");
  
  effectList.PushString("beam_ring15");
  niceNameList.PushString("Rainbow | Rainbow 4");
  
  effectList.PushString("beam_mix_rainbow3");
  niceNameList.PushString("Rainbow | Rainbow (2 Rings)");
  
  effectList.PushString("beam_mix_rainbow7");
  niceNameList.PushString("Rainbow | Rainbow (2 Rings, Wide Bottom)");
  
  effectList.PushString("beam_mix_rainbow6");
  niceNameList.PushString("Rainbow | Rainbow (2 Rings, Wide Top)");
  
  effectList.PushString("beam_mix_rainbow4");
  niceNameList.PushString("Rainbow | Rainbow (3 Rings)");
  
  effectList.PushString("beam_mix_ring2");
  niceNameList.PushString("Rainbow | Cylinder (2 Rings)");
  
  effectList.PushString("beam_mix_thunder");
  niceNameList.PushString("Thunder Rings/Clouds | Electric");
  
  effectList.PushString("beam_mix_thunder2");
  niceNameList.PushString("Thunder Rings/Clouds | Teal");
  
  effectList.PushString("beam_thunder");
  niceNameList.PushString("Thunder Rings/Clouds | Pulse Electric");
  
  effectList.PushString("beam_lightningcloud");
  niceNameList.PushString("Thunder Rings/Clouds | Lightning (White Cloud)");
  
  effectList.PushString("beam_cloud");
  niceNameList.PushString("Thunder Rings/Clouds | Cloud (Blue Cloud)");
  
  effectList.PushString("beam_nimbus");
  niceNameList.PushString("Thunder Rings/Clouds | Flying Nimbus (Yellow Cloud)");
  
  effectList.PushString("beam_mix_vortex2");
  niceNameList.PushString("Vortex Rings | Red");
  
  effectList.PushString("beam_mix_vortex3");
  niceNameList.PushString("Vortex Rings | Rainbow");
  
  effectList.PushString("beam_mix_vortex6");
  niceNameList.PushString("Vortex Rings | Rainbow 2");
  
  effectList.PushString("beam_mix_vortex4");
  niceNameList.PushString("Vortex Rings | Frost (White)");
  
  effectList.PushString("beam_vixr_body");
  niceNameList.PushString("Vortex Rings | White");
  
  effectList.PushString("beam_ringglow3");
  niceNameList.PushString("Vortex Rings | Purple/Red Glow");
  
  effectList.PushString("beam_ringglow5");
  niceNameList.PushString("Vortex Rings | Blue Splatter Glow");
  
  effectList.PushString("beam_mix_ring5");
  niceNameList.PushString("Vortex Rings | Fuzzing 1 (Blue)");
  
  effectList.PushString("beam_mix_ring7");
  niceNameList.PushString("Vortex Rings | Teal 1");
  
  effectList.PushString("beam_ring16");
  niceNameList.PushString("Vortex Rings | Teal 2");
  
  effectList.PushString("beam_mix_redring");
  niceNameList.PushString("Vortex Rings | Hell Ring + Trail");
  
  effectList.PushString("beam_reminiscences");
  niceNameList.PushString("Miscellaneous | Reminiscences"); 
  
  effectList.PushString("beam_bubble2");
  niceNameList.PushString("Miscellaneous | Bubbles (Green + Ring)"); 
  
  effectList.PushString("beam_donuts");
  niceNameList.PushString("Miscellaneous | Donuts (Pink)"); 
  
  effectList.PushString("beam_leaf");
  niceNameList.PushString("Miscellaneous | Leaf (Spring)"); 
  
  //Set total number of particles
  s_NumParticleStyles = effectList.Length;
  
  for (int i = 0; i < s_NumParticleStyles; ++i) {
    Format(ParticleBeams_List[i][szParticleName], PLATFORM_MAX_PATH, PARTICLE_PCF_FILE);
    
    char buffer[PLATFORM_MAX_PATH];
    effectList.GetString(i, buffer, sizeof(buffer));
    Format(ParticleBeams_List[i][szEffectName], PLATFORM_MAX_PATH, buffer);
    
    char niceNamebuffer[64];
    niceNameList.GetString(i, niceNamebuffer, sizeof(niceNamebuffer));
    Format(ParticleBeams_List[i][szNiceName], PLATFORM_MAX_PATH, niceNamebuffer);
  }
  
  delete effectList;
  delete niceNameList;
}

//OnMapStart
public void ParticleBeams_OnMapStart()
{
  for(int i = 0; i < s_NumParticleStyles; ++i) {
    ParticleBeams_List[i][iCacheID] = PrecacheGeneric(ParticleBeams_List[i][szParticleName], true);
    AddFileToDownloadsTable(ParticleBeams_List[i][szParticleName]);
  }
}

public void ParticleBeams_PlaceBeam(int client, float duration, float position[3])
{
  int m_unEnt = CreateEntityByName("info_particle_system");
  
  if (IsValidEntity(m_unEnt))
  {
    DispatchKeyValue(m_unEnt, "start_active", "1");
    DispatchKeyValue(m_unEnt, "effect_name", ParticleBeams_List[s_CurParticleStyle][szEffectName]);
    DispatchSpawn(m_unEnt);

    TeleportEntity(m_unEnt, position, NULL_VECTOR, NULL_VECTOR);
    
    ActivateEntity(m_unEnt);
    
    //Create timer for removal
    CreateTimer(duration, ParticleBeams_RemoveParticle, EntIndexToEntRef(m_unEnt));
  }
}

//Kill a given particle beam using its reference
public Action ParticleBeams_RemoveParticle(Handle timer, int entref)
{
  int m_unEnt = EntRefToEntIndex(entref);
  
  if (m_unEnt == INVALID_ENT_REFERENCE)
    return Plugin_Handled;
 
  AcceptEntityInput(m_unEnt, "Kill");
  
  return Plugin_Handled;
}

//Setters/Getters
public int ParticleBeams_GetNumParticleStyles()
{
  return s_NumParticleStyles;
}

public int ParticleBeams_GetStyle()
{
  return s_CurParticleStyle;
}

public void ParticleBeams_SetStyle(int newStyle)
{
  s_CurParticleStyle = newStyle;
}
