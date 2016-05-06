#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include "colors_csgo.inc"
#include "warden.inc"
#include "voiceannounce_ex.inc"
#include "emitsoundany.inc"

UserMsg g_FadeUserMsgId; //For Blind

//Defines
#define VERSION "1.23"
#define CHAT_TAG_PREFIX "[{pink}Warden Tools{default}] "

#define COLOUR_DEFAULT 0
#define COLOUR_RED 1
#define COLOUR_GREEN 2
#define COLOUR_BLUE 3
#define COLOUR_PURPLE 4
#define COLOUR_YELLOW 5
#define COLOUR_CYAN 6
#define COLOUR_PINK 7
#define COLOUR_ORANGE 8
#define COLOUR_WHITE 9
#define COLOUR_BLACK 10

#define SPECIALDAY_NONE 0
#define SPECIALDAY_CUSTOM 1
#define SPECIALDAY_FREEDAY 2
#define SPECIALDAY_ROUNDMODIFIER 3
#define SPECIALDAY_HNS 4
#define SPECIALDAY_WARDAY 5
#define SPECIALDAY_VIRUSDAY 6
#define SPECIALDAY_FFADM 7
#define SPECIALDAY_TEAMDM 8
#define SPECIALDAY_HUNGERGAMES 9

#define ROUNDMODIFIER_NONE 0
#define ROUNDMODIFIER_LOWGRAVITY 1
#define ROUNDMODIFIER_FASTSPEED 2
#define ROUNDMODIFIER_WALKINGONLY 3

#define TELEPORTTYPE_ALL 0
#define TELEPORTTYPE_T 1

#define INFECT_SOUND_1 "invex_gaming/jb_wardentools/infected_1.mp3"
#define INFECT_SOUND_2 "invex_gaming/jb_wardentools/infected_2.mp3"
#define INFECT_SOUND_3 "invex_gaming/jb_wardentools/infected_3.mp3"
#define INFECT_DEATH_SOUND_1 "invex_gaming/jb_wardentools/infected_death1.mp3"
#define INFECT_DEATH_SOUND_2 "invex_gaming/jb_wardentools/infected_death2.mp3"
#define JAWS_SOUND "invex_gaming/jb_wardentools/jaws_theme.mp3"

#define SHORT_1 "invex_gaming/jb_wardentools/short_gotcha_bitch.mp3"
#define SHORT_2 "invex_gaming/jb_wardentools/short_shut_your.mp3"
#define SHORT_3 "invex_gaming/jb_wardentools/short_oh_baby_a_triple.mp3"
#define SHORT_4 "invex_gaming/jb_wardentools/short_get_noscoped.mp3"
#define SHORT_5 "invex_gaming/jb_wardentools/short_suprise_mother.mp3"
#define SHORT_6 "invex_gaming/jb_wardentools/short_hax.mp3"
#define SHORT_7 "invex_gaming/jb_wardentools/short_nathan_knew.mp3"

#define HIDE_RADAR_CSGO 1<<12

//Materials
int g_BeamSprite;
int g_HaloSprite;

//Cvars
ConVar cvar_maxbeams = null;
ConVar cvar_maxunits = null;
ConVar cvar_maxspecialdays = null;
ConVar cvar_hns_cthealth = null;
ConVar cvar_hns_tptime = null;
ConVar cvar_shark_health = null;
ConVar cvar_shark_duration = null;
ConVar cvar_shark_timeleft_warning = null;
ConVar cvar_hns_thealth = null;
ConVar cvar_hns_ctfreezetime = null;
ConVar cvar_hns_hiderswintime = null;
ConVar cvar_warday_tptime = null;
ConVar cvar_miccheck_time = null;
ConVar cvar_specialday_starttime = null;
ConVar cvar_virusday_tptime = null;
ConVar cvar_virusday_hidetime = null;
ConVar cvar_virusday_noninfectedwintime = null;
ConVar cvar_virusday_infectedhealth = null;
ConVar cvar_virusday_infectedspeed = null;
ConVar cvar_virusday_infectedgravity = null;
ConVar cvar_virusday_min_drain = null;
ConVar cvar_virusday_max_drain = null;
ConVar cvar_virusday_drain_interval = null;
ConVar cvar_ffadm_tptime = null;
ConVar cvar_ffadm_hidetime = null;
ConVar cvar_ffadm_slaytime = null;
ConVar cvar_ffadm_autobeacontime = null;
ConVar cvar_teamdm_slaytime = null;
ConVar cvar_teamdm_tptime = null;
ConVar cvar_teamdm_hidetime = null;
ConVar cvar_teamdm_autobeacontime = null;
ConVar cvar_hungergames_tptime = null;
ConVar cvar_hungergames_hidetime = null;
ConVar cvar_hungergames_slaytime = null;
ConVar cvar_hungergames_min_random_health = null;
ConVar cvar_hungergames_max_random_health = null;
ConVar cvar_hungergames_autobeacontime = null;
ConVar cvar_roundmodifier_lowgravity = null;
ConVar cvar_roundmodifier_walkingonly_maxspeed = null;
ConVar cvar_roundmodifier_fastspeed = null;
ConVar cvar_roundmodifier_fastspeed_gravity = null;

//Menus
Menu MainMenu = null;
Menu GameMenu = null;
Menu DrawMenu = null;
Menu SpecialDaysMenu = null;

//Beam Settings
float curDuration = 20.0;
int redColour[4] = {255, 0, 0, 200};
int greenColour[4] = {0, 255, 0, 200};
int blueColour[4] = {0, 0, 255, 200};
int purpleColour[4] = {128, 112, 214, 200};
int yellowColour[4] = {255, 255, 0, 200};
int cyanColour[4] = {0, 255, 255, 200};
int pinkColour[4] = {255, 105, 180, 200};
int orangeColour[4] = {255, 140, 0, 200};
int whiteColour[4] = {254, 254, 254, 200};
int blackColour[4] = {1, 1, 1, 200};
int currentColour[4] = {255, 0, 0, 200}; //red is default
int currentColourCode = COLOUR_RED;
int currentBeamsUsed = 0;

//Settings
int newRoundTimeElapsed = 0;
int orig_sv_gravity = 800;
int orig_sv_maxspeed = 320;
bool specialDayDamageProtection = false;
bool shouldBlindT = false;
bool shouldFreezeT = false;
Handle freezeTimer = null; 
bool isBlind[MAXPLAYERS+1] = false;
Handle teleportHandle = null;
Handle damageProtectionHandle = null;

bool isHighlighted[MAXPLAYERS+1] = false;
int highlightedColour[MAXPLAYERS+1] = COLOUR_DEFAULT;
bool isInHighlightTeamDM = false;

int specialDay = SPECIALDAY_NONE;

int roundModifier = ROUNDMODIFIER_NONE;

ArrayList micSwapTargets;
bool micCheckConducted = false;
bool isInMicCheckTime = false;

bool isShark[MAXPLAYERS+1] = false;

bool isInfected[MAXPLAYERS+1] = false;
bool isInInfectedHideTime = false;
int infectedIcon[MAXPLAYERS+1] = {-1, ...};
bool isPastCureFoundTime = false;
Handle virusdayNonInfectedWinHandle = null;
Handle drainTimer = null;
Handle infectionStartTimer = null;

Handle freeforallRoundEndHandle = null;
Handle freeforallStartTimer = null;
bool isFFARoundStalemate = false;
bool isPastHideTime = false;

Handle hnsPrisonersWinHandle = null;

Handle autoBeaconHandle = null;

char clantagStorage[MAXPLAYERS+1][32];
bool restoreClanTags = false;

//Per map settings
int numSpecialDays = 0;
bool isFirstRound = false;

//Laser
int g_DefaultColors_c[7][4] = { {255,255,255,255}, {255,0,0,255}, {0,255,0,255}, {0,0,255,255}, {255,255,0,255}, {0,255,255,255}, {255,0,255,255} };
float LastLaser[MAXPLAYERS+1][3];
bool LaserEnabled[MAXPLAYERS+1] = {false, ...};

public Plugin myinfo =
{
  name = "Jailbreak Warden Tools",
  author = "Invex | Byte",
  description = "Tools to help the warden...warden.",
  version = VERSION,
  url = "http://www.invexgaming.com.au"
};

/*********************************
 *   Fowards
 *********************************/

// Plugin Start
public void OnPluginStart()
{
  //Translations
  LoadTranslations("wardentools.phrases");
  
  //Flags
  CreateConVar("sm_wardentools_version", VERSION, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);
  
  RegConsoleCmd("sm_wt", Command_WT_Menu, "Bring up warden tools menu");
  RegConsoleCmd("sm_wardentools", Command_WT_Menu, "Bring up warden tools menu");
  
  //Update new round time start
  newRoundTimeElapsed = GetTime();
  
  //Hooks
  HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
  HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
  HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

  //For blind
  g_FadeUserMsgId = GetUserMessageId("Fade");
  
  // Create ConCommands
  RegConsoleCmd("+beam", PlaceBeamAction, "", FCVAR_GAMEDLL);
  RegConsoleCmd("+sm_laser", PlaceLaserAction, "");
  RegConsoleCmd("-sm_laser", RemoveLaserAction, "");
  RegAdminCmd("sm_miccheck", Command_MicCheck, ADMFLAG_GENERIC, "Conduct a mic check");
  RegAdminCmd("sm_mc", Command_MicCheck, ADMFLAG_GENERIC, "Conduct a mic check");
 
  //Cvars
  cvar_maxbeams = CreateConVar("sm_wardentools_maxbeams", "7", "Maximum number of beams that can be spawned at any given time (def. 7)");
  cvar_maxunits = CreateConVar("sm_wardentools_maxunits", "1500", "Maximum number of units a beam can be spawned from the player (def. 1000)");
  cvar_maxspecialdays = CreateConVar("sm_wardentools_maxspecialdays", "4", "Maximum number of special days per map (def. 4)");
  cvar_specialday_starttime = CreateConVar("sm_wardentools_specialday_starttime", "60.0", "The amount of time the warden has to trigger a special day (def. 60.0)");
  cvar_hns_cthealth = CreateConVar("sm_wardentools_hns_cthealth", "32000", "Health CT's get (def. 32000)");
  cvar_hns_thealth = CreateConVar("sm_wardentools_hns_thealth", "65", "Health T's get (def. 65)");
  cvar_hns_ctfreezetime = CreateConVar("sm_wardentools_hns_ctfreezetime", "90", "Number of seconds CT's should be frozen (def. 90)");
  cvar_hns_tptime = CreateConVar("sm_wardentools_hns_tptime", "10.0", "The amount of time before prisoners are teleported to start beacon (def. 10.0)");
  cvar_hns_hiderswintime = CreateConVar("sm_wardentools_hns_hiderswintime", "420.0", "The amount of time before prisoners win the hide and seek round (def. 420.0)");
  cvar_shark_health = CreateConVar("sm_wardentools_shark_health", "32000", "Health CT Sharks get (def. 32000)");
  cvar_shark_duration = CreateConVar("sm_wardentools_shark_duration", "30.0", "The amount of time a shark should remain as a shark (def. 30.0)");
  cvar_shark_timeleft_warning = CreateConVar("sm_wardentools_shark_timeleft_warning", "5.0", "How many seconds should be left before a warning is shown (def. 5.0)");
  cvar_warday_tptime = CreateConVar("sm_wardentools_warday_tptime", "30.0", "The amount of time before prisoners are teleported to start beacon (def. 30.0)");
  cvar_miccheck_time = CreateConVar("sm_wardentools_miccheck_time", "15.0", "The amount of time guards have to use their mic in a mic check (def. 15.0)");
  
  cvar_virusday_tptime = CreateConVar("sm_wardentools_virusday_tptime", "10.0", "The amount of time before prisoners are teleported to start beacon (def. 10.0)");
  cvar_virusday_hidetime = CreateConVar("sm_wardentools_virusday_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  cvar_virusday_noninfectedwintime = CreateConVar("sm_wardentools_virusday_noninfectedwintime", "420.0", "The amount of time before non infected win the virus day (def. 420.0)");
  cvar_virusday_infectedhealth = CreateConVar("sm_wardentools_virusday_infectedhealth", "3000", "Health each infected gets (def. 3000)");
  cvar_virusday_infectedspeed = CreateConVar("sm_wardentools_virusday_infectedspeed", "1.35", "The speed multiplier the infected get (def. 1.35)");
  cvar_virusday_infectedgravity = CreateConVar("sm_wardentools_virusday_infectedgravity", "0.8", "The gravity infected zombies get (def. 0.8)");
  cvar_virusday_min_drain = CreateConVar("sm_wardentools_virusday_min_drain", "12", "Minimum amount of HP that can be taken away during a drain (def. 12)");
  cvar_virusday_max_drain = CreateConVar("sm_wardentools_virusday_max_drain", "60", "Maximum amount of HP that can be taken away during a drain (def. 60)");
  cvar_virusday_drain_interval = CreateConVar("sm_wardentools_virusday_drain_interval", "1.0", "Interval of time between every drain (def. 1.0)");
  
  cvar_ffadm_tptime = CreateConVar("sm_wardentools_ffadm_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  cvar_ffadm_hidetime = CreateConVar("sm_wardentools_ffadm_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  cvar_ffadm_slaytime = CreateConVar("sm_wardentools_ffadm_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  cvar_ffadm_autobeacontime = CreateConVar("sm_wardentools_ffadm_autobeacontime", "300.0", "The amount of time before all players are beaconed and told to actively hunt (def. 300.0)");
  
  cvar_hungergames_tptime = CreateConVar("sm_wardentools_hungergames_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  cvar_hungergames_hidetime = CreateConVar("sm_wardentools_hungergames_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  cvar_hungergames_slaytime = CreateConVar("sm_wardentools_hungergames_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  cvar_hungergames_min_random_health = CreateConVar("sm_wardentools_hungergames_min_random_health", "100.0", "The lower bound for randomised health for hunger games (def. 75.0)");
  cvar_hungergames_max_random_health = CreateConVar("sm_wardentools_hungergames_max_random_health", "175.0", "The upper bound for randomised health for hunger games (def. 125.0)");
  cvar_hungergames_autobeacontime = CreateConVar("sm_wardentools_hungergames_autobeacontime", "300.0", "The amount of time before all players are beaconed and told to actively hunt (def. 300.0)");
  
  cvar_roundmodifier_lowgravity = CreateConVar("sm_wardentools_roundmodifier_lowgravity", "250", "The gravity all players play with (def. 250)");
  cvar_roundmodifier_fastspeed = CreateConVar("sm_wardentools_roundmodifier_fastspeed", "1.75", "The speed all players play with (def. 1.75)");
  cvar_roundmodifier_fastspeed_gravity = CreateConVar("sm_wardentools_roundmodifier_fastspeed_gravity", "0.65", "The gravity to aid fast speed (def. 0.65)");
  cvar_roundmodifier_walkingonly_maxspeed = CreateConVar("sm_wardentools_roundmodifier_walkingonly_maxspeed", "125", "The maximum speed all players play with (def. 125)");
  
  cvar_teamdm_tptime = CreateConVar("sm_wardentools_teamdm_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  cvar_teamdm_hidetime = CreateConVar("sm_wardentools_teamdm_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  cvar_teamdm_slaytime = CreateConVar("sm_wardentools_teamdm_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  cvar_teamdm_autobeacontime = CreateConVar("sm_wardentools_teamdm_autobeacontime", "300.0", "The amount of time before all players are beaconed and told to actively hunt (def. 300.0)");
  
  //Create array
  micSwapTargets = CreateArray();
  
  //Original convars
  orig_sv_gravity = GetConVarInt(FindConVar("sv_gravity"));
  orig_sv_maxspeed = GetConVarInt(FindConVar("sv_maxspeed"));
  
  //SDKHooks
  int iMaxClients = GetMaxClients();
  
  for (int i = 1; i <= iMaxClients; ++i) {
    if (IsClientInGame(i)) {
      OnClientPutInServer(i);
    }
  }
  
  //Create config file
  AutoExecConfig(true, "wardentools");
}

// On map start
public void OnMapStart()
{
  AddFileToDownloadsTable("materials/sprites/laserbeam.vmt");
  AddFileToDownloadsTable("materials/sprites/laserbeam.vtf");
  AddFileToDownloadsTable("materials/sprites/halo01.vmt");
  AddFileToDownloadsTable("materials/sprites/halo01.vtf");
  
  //Precache materials
  g_BeamSprite = PrecacheModel("sprites/laserbeam.vmt", true);
  g_HaloSprite = PrecacheModel("sprites/halo01.vmt", true);
  
  //Precache sounds
  char precacheSounds[13][] = {INFECT_SOUND_1, INFECT_SOUND_2, INFECT_SOUND_3, INFECT_DEATH_SOUND_1, INFECT_DEATH_SOUND_2, JAWS_SOUND, SHORT_1, SHORT_2, SHORT_3, SHORT_4, SHORT_5, SHORT_6, SHORT_7};
  
  for (int i = 0; i < sizeof(precacheSounds); ++i) {
    char downloadPath[PLATFORM_MAX_PATH];
    Format(downloadPath, sizeof(downloadPath), "sound/%s", precacheSounds[i]);
    AddFileToDownloadsTable(downloadPath);
    PrecacheSoundAny(precacheSounds[i]);
  }
  
  //Precache overlay decals
  AddFileToDownloadsTable("materials/overlays/invex/infectedblood.vtf");
  AddFileToDownloadsTable("materials/overlays/invex/infectedblood.vmt");
  PrecacheDecal("overlays/invex/infectedblood.vtf", true);
  PrecacheDecal("overlays/invex/infectedblood.vmt", true);
  
  //Precache infected icon
  AddFileToDownloadsTable("materials/sprites/invex/infected.vmt");
  AddFileToDownloadsTable("materials/sprites/invex/infected.vtf");
  PrecacheModel("materials/sprites/invex/infected.vmt", true);
  
  //Laser timer
  CreateTimer(0.1, Timer_Check_Laser, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
  
  //Reset Special days
  numSpecialDays = 0;
  
  //1st round after map change
  isFirstRound = true;
}

//Client put in server
public void OnClientPutInServer(int client)
{
  LaserEnabled[client] = false;
  LastLaser[client][0] = 0.0;
  LastLaser[client][1] = 0.0;
  LastLaser[client][2] = 0.0;
  
  //Shouldn't be blind or highlighted when first joining
  isBlind[client] = false;
  isHighlighted[client] = false;
  isShark[client] = false;
  isInfected[client] = false;
  
  //Shouldn't have a preserved clan tag
  clantagStorage[client] = "";
  
  //SDK Hooks
  SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage)
  SDKHook(client, SDKHook_WeaponCanUse, BlockPickup);
}

//Called when a player takes damage
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  //Ignore invalid entities
  if (!(victim > 0 && victim <= MaxClients) || !(attacker > 0 && attacker <= MaxClients)) {
    return Plugin_Continue;
  }
  
  if (isInHighlightTeamDM) {
    
    //Check for CT's trying to kill each other
    if (GetClientTeam(victim) == CS_TEAM_CT && GetClientTeam(attacker) == CS_TEAM_CT) {
      return Plugin_Handled;
    }
    
    //Check for T's trying to kill team mates
    if (GetClientTeam(victim) == CS_TEAM_T && GetClientTeam(attacker) == CS_TEAM_T) {
      if (isHighlighted[victim] && isHighlighted[attacker]) {
        if (highlightedColour[victim] == highlightedColour[attacker]) {
          return Plugin_Handled;
        }
      }
      
      //Check for T's killing non highlighted T's
      if (!isHighlighted[attacker]) {
        return Plugin_Handled;
      }
      
      if (isHighlighted[attacker] && !isHighlighted[victim]) {
        return Plugin_Handled;
      }
    }
  }
  
  //If damage should be blocked for another reason
  if (specialDay) {
    if (specialDay == SPECIALDAY_VIRUSDAY) {
      if (isInfected[attacker] && !isInfected[victim]) {
        VirusDay_InfectClient(victim, true);
      }
      //Non infected can harm the infected
      else if (!isInfected[attacker] && isInfected[victim]) {
        return Plugin_Continue;
      }
      
      return Plugin_Handled;
    }
    else if (specialDay == SPECIALDAY_TEAMDM && isPastHideTime) {
      //Check for player trying to kill team mates
      //Everybody should be highlighted and on a team so this is sufficient
      if (isHighlighted[victim] && isHighlighted[attacker]) {
        if (highlightedColour[victim] == highlightedColour[attacker]) {
          return Plugin_Handled;
        }
      }
    }
    else if (specialDayDamageProtection) {
      return Plugin_Handled;
    }
  }
  
  return Plugin_Continue;
}

/*********************************
 *  Events
 *********************************/
//Round start
public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
  //Reset vars
  Reset_Vars();
 
  //Enforce 1st round freeday
  if (isFirstRound) {
    specialDay = SPECIALDAY_FREEDAY;
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Freeday");
    isFirstRound = false;
  }
}

//Player death hook
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  //Unblind all clients on death who are blind
  int client = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  
  bool isWarden = view_as<bool>(warden_iswarden(client));
  
  if (isBlind[client]) {
    Handle fadePack;
    CreateDataTimer(0.0, UnfadeClient, fadePack);
    WritePackCell(fadePack, client);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 0);
  }
  
  //Warden just died
  if (isWarden) {
    //Kill all menus for warden
    CancelClientMenu(client);
    
    //Close menu handlers
    if (MainMenu != null) delete MainMenu;
    if (GameMenu != null) delete GameMenu;
    if (DrawMenu != null) delete DrawMenu;
    if (SpecialDaysMenu != null) delete SpecialDaysMenu;
    
    //Turn off laser for warden
    RemoveLaserAction(client, 0);
    
    //Cancel any active team DM's
    if (isInHighlightTeamDM) {
      //Warden died so stop team DM
      turnOffTeamDM();
    }
  }
  
  //Check if team DM should be stopped
  if (isInHighlightTeamDM) {
    //Check team counts
    int teamsLeft = getTeamDMNumTeamsAlive_TOnly();

    if (teamsLeft <= 1) {
      //Last team left or everybody has died, auto turn off team DM
      turnOffTeamDM();
    }
    
  }
  
  if (specialDay) {
    if (specialDay == SPECIALDAY_VIRUSDAY) {
    
      if (!isInInfectedHideTime) {
        VirusDay_CheckInfectedOver();
        
        if (isInfected[client]) {
          SafeDelete(infectedIcon[client]);
          infectedIcon[client] = -1;
          
          //Remove fade
          Handle fadePack;
          CreateDataTimer(0.0, UnfadeClient, fadePack);
          WritePackCell(fadePack, client);
          WritePackCell(fadePack, 0);
          WritePackCell(fadePack, 0);
          WritePackCell(fadePack, 0);
          WritePackCell(fadePack, 0);
        }
      }
      
      if (isInfected[client] && !isInfected[attacker]) {
        if (attacker != 0)
          CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Virus Day Infected Killed", attacker, client);
        
        //Play sound
        char infectDeathSounds[2][] = {INFECT_DEATH_SOUND_1, INFECT_DEATH_SOUND_2};
        int randNum = GetRandomInt(0, sizeof(infectDeathSounds) - 1);

        //Play explosion sounds
        EmitSoundToAllAny(infectDeathSounds[randNum], client, SNDCHAN_USER_BASE, SNDLEVEL_RAIDSIREN); 
        
        //Make burn appear in kill feed
        if (isPastCureFoundTime) {
          event.SetString("weapon", "inferno");
        }
      }
    }
    else if (specialDay == SPECIALDAY_HNS) {
      if (GetClientTeam(client) == CS_TEAM_T) {
        //Play death  sound for them
        char hnsDeathSounds[7][] = {SHORT_1, SHORT_2, SHORT_3, SHORT_4, SHORT_5, SHORT_6, SHORT_7};
        int randNum = GetRandomInt(0, sizeof(hnsDeathSounds) - 1);
        
        //Play explosion sounds
        EmitSoundToAllAny(hnsDeathSounds[randNum], client, SNDCHAN_USER_BASE, SNDLEVEL_RAIDSIREN); 
      }
    }
    else if (specialDay == SPECIALDAY_FFADM || specialDay == SPECIALDAY_HUNGERGAMES) {
      //Count number of alive players
      int numAlive = 0;
      int lastAliveClient = -1;
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          ++numAlive;
          lastAliveClient = i;
        }
      }
      
      //Check if there is only 1 remaining player
      if (numAlive == 1 && lastAliveClient != -1 && !isFFARoundStalemate) {
        if (specialDay == SPECIALDAY_FFADM)
          CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Free For All Winner", lastAliveClient, "FFA Deathmatch");
        else if (specialDay == SPECIALDAY_HUNGERGAMES)
          CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Free For All Winner", lastAliveClient, "Hunger Games");
      }
    }
    else if (specialDay == SPECIALDAY_TEAMDM && isPastHideTime) {
      //Check if team DM should be stopped
      int teamsLeft = getTeamDMNumTeamsAlive();

      if (teamsLeft <= 1) {
        //Find winning team
        int winningTeamCode = COLOUR_DEFAULT;
        
        for (int i = 1; i <= MaxClients; ++i) {
          if (IsClientInGame(i) && IsPlayerAlive(i)) {
            if (isHighlighted[i]) {
              winningTeamCode = highlightedColour[i];
              break;
            }
          }
        }
      
        //Print message to all
        if (winningTeamCode == COLOUR_RED)
          CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "darkred", "red");
        else if (winningTeamCode == COLOUR_BLUE)
          CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "blue", "blue");
        else if (winningTeamCode == COLOUR_GREEN)
          CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "lightgreen", "green");
        else if (winningTeamCode == COLOUR_YELLOW)
          CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "olive", "yellow");
        else if (winningTeamCode == COLOUR_BLACK)
          CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Winner", "default", "black");

        //End the round
        CS_TerminateRound(GetConVarFloat(FindConVar("mp_round_restart_delay")), CSRoundEnd_CTWin, false);
      }
    }
  }
  
  return Plugin_Continue;
}

//Player spawn hook
public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (specialDay && specialDay == SPECIALDAY_ROUNDMODIFIER && roundModifier == ROUNDMODIFIER_FASTSPEED) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", GetConVarFloat(cvar_roundmodifier_fastspeed));
    SetEntityGravity(client, GetConVarFloat(cvar_roundmodifier_fastspeed_gravity));
  }
}

/*********************************
 *  Console Commands
 *********************************/

//Show WT Menu
public Action Command_WT_Menu(int client, int args)
{
  if (client == 0) {  // Prevent command usage from server input and via RCON
    PrintToConsole(client, "Can't use this command from server input.");
    return Plugin_Handled;
  }
  
  //Ensure team is CT
  if (GetClientTeam(client) != CS_TEAM_CT) { 
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "CT Only Command");
    return Plugin_Handled;
  }
  
  //Ensure user is warden
  bool isWarden = view_as<bool>(warden_iswarden(client));
  
  if (!isWarden) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
    return Plugin_Handled;
  }
  
  //Create menu
  MainMenu = CreateMenu(MainMenuHandler);
  char mainMenuTitle[255];
  Format(mainMenuTitle, sizeof(mainMenuTitle), "Warden Tools (%s)", VERSION);
  SetMenuTitle(MainMenu, mainMenuTitle);
  
  //Add menu items
  if (!specialDay || (specialDay && (specialDay == SPECIALDAY_FREEDAY || specialDay == SPECIALDAY_ROUNDMODIFIER || specialDay == SPECIALDAY_CUSTOM)))
    AddMenuItem(MainMenu, "Option_DrawTools", "Draw Tools");
  else
    AddMenuItem(MainMenu, "Option_DrawTools", "Draw Tools", ITEMDRAW_DISABLED);
  
  //Game tools only enabled on non-special days or on round modifier days
  if (!specialDay || (specialDay && specialDay == SPECIALDAY_ROUNDMODIFIER))  
    AddMenuItem(MainMenu, "Option_GameTools", "Game Tools");
  else
    AddMenuItem(MainMenu, "Option_GameTools", "Game Tools", ITEMDRAW_DISABLED);
    
  //Disable special day menu if one already running
  char specialDayText[64];
  Format(specialDayText, sizeof(specialDayText), "Special Days (%d left)", GetConVarInt(cvar_maxspecialdays) - numSpecialDays);
  
  if (specialDay || (GetConVarInt(cvar_maxspecialdays) - numSpecialDays) == 0)
    AddMenuItem(MainMenu, "Option_SpecialDay", specialDayText, ITEMDRAW_DISABLED);
  else if (GetTimeSinceRoundStart() >= GetConVarInt(cvar_specialday_starttime))
    AddMenuItem(MainMenu, "Option_SpecialDay", specialDayText, ITEMDRAW_DISABLED);
  else
    AddMenuItem(MainMenu, "Option_SpecialDay", specialDayText);
   
  if (micCheckConducted)
    AddMenuItem(MainMenu, "Option_MicCheck", "Perform Mic Check", ITEMDRAW_DISABLED);
  else
    AddMenuItem(MainMenu, "Option_MicCheck", "Perform Mic Check");
  
  AddMenuItem(MainMenu, "Option_PriorityToggle", "Priority Speaker [Toggle]");
  
  DisplayMenu(MainMenu, client, MENU_TIME_FOREVER);
  
  return Plugin_Handled;
}

//Perform Mic check
public Action Command_MicCheck(int client, int args) {
  if (micCheckConducted) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Miccheck Already Conducted");
    return Plugin_Handled;
  }
  else if (isInMicCheckTime) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Miccheck Already Happening");
    return Plugin_Handled;
  }
  
  //Say who started a mic check
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Miccheck Started All", client);
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_CT) {
        //Perform Mic Check
        CPrintToChat(i, "%s%t", CHAT_TAG_PREFIX, "Miccheck Started CT", client, RoundToNearest(GetConVarFloat(cvar_miccheck_time)));
        PrintHintText(i, "%t", "Miccheck Status Not Verified");
        PushArrayCell(micSwapTargets, i);
        CreateTimer(0.5, Timer_MicCheck, i);
      }
    }
  }
  
  isInMicCheckTime = true;
  micCheckConducted = true;
  
  //Create timer to stop mic check
  CreateTimer(GetConVarFloat(cvar_miccheck_time), Timer_MicCheckFinish);

  return Plugin_Handled;
}


/*********************************
 *  Menus and Handlers
 *********************************/

//Handles main Menu
public int MainMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    
    if (StrEqual(info, "Option_DrawTools")) {
      //Create menu
      DrawMenu = CreateMenu(DrawMenuHandler);
      SetMenuExitBackButton(DrawMenu, true);
      SetMenuTitle(DrawMenu, "Use a drawing tool");
      
      //Add menu items
      AddMenuItem(DrawMenu, "Option_SpawnBeam", "Spawn Beam");
      AddMenuItem(DrawMenu, "Option_SetColour", "Set Colour");
      AddMenuItem(DrawMenu, "Option_BeamDuration", "Toggle Beam Duration");
      AddMenuItem(DrawMenu, "Option_Laser", "Laser [Toggle]");
      AddMenuItem(DrawMenu, "Option_Highlight", "Highlight Prisoner [Toggle]");
      AddMenuItem(DrawMenu, "Option_ClearHighlight", "Clear Highlights");

      DisplayMenu(DrawMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_GameTools")) {
      //Create menu
      GameMenu = CreateMenu(GameMenuHandler);
      SetMenuExitBackButton(GameMenu, true);
      SetMenuTitle(GameMenu, "Select an effect");
      
      //Add menu items
      AddMenuItem(GameMenu, "Option_Slap", "Slap Prisoners");
      AddMenuItem(GameMenu, "Option_Freezebomb", "Freezebomb Prisoners (Toggle)");
      AddMenuItem(GameMenu, "Option_Blind", "Blind Prisoners (Toggle)");
      AddMenuItem(GameMenu, "Option_CTShark", "Make CT Shark (30 seconds)");
      AddMenuItem(GameMenu, "Option_HighlightedDM", "Highlighted Team Deathmatch (Toggle)");
      
      DisplayMenu(GameMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_SpecialDay")) {
      //Create menu
      SpecialDaysMenu = CreateMenu(SpecialDaysMenuHandler);
      SetMenuExitBackButton(SpecialDaysMenu, true);
      SetMenuTitle(SpecialDaysMenu, "Select a Special Day");
      
      //Add menu items
      AddMenuItem(SpecialDaysMenu, "Option_Freeday", "Freeday");
      AddMenuItem(SpecialDaysMenu, "Option_RoundModifiers", "Round Modifiers");
      AddMenuItem(SpecialDaysMenu, "Option_CustomDay", "Custom Special Day");
      AddMenuItem(SpecialDaysMenu, "Option_HNS", "Hide and Seek Day");
      AddMenuItem(SpecialDaysMenu, "Option_Warday", "Warday");
      AddMenuItem(SpecialDaysMenu, "Option_VirusDay", "Zombie Day");
      AddMenuItem(SpecialDaysMenu, "Option_FFADM", "FFA Deathmatch Day");
      AddMenuItem(SpecialDaysMenu, "Option_TeamDM", "Team Deathmatch Day");
      AddMenuItem(SpecialDaysMenu, "Option_HungerGamesDay", "Hunger Games Day");
      
      DisplayMenu(SpecialDaysMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_MicCheck")) {
      Command_MicCheck(client, 0);
    }
    else if (StrEqual(info, "Option_PriorityToggle")) {
      //Toggle Cvar value
      ConVar priorityToggle = FindConVar("sm_wardentalk2_enabled");
      if (priorityToggle != null) {
        SetConVarBool(priorityToggle, !GetConVarBool(priorityToggle));
      }
      
      //Print messages
      if (GetConVarBool(priorityToggle))
        CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Priority Talk Toggle", "green", "enabled");
      else
        CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Priority Talk Toggle", "darkred", "disabled");
      
      DisplayMenu(MainMenu, client, MENU_TIME_FOREVER);
    }
  }
}

//Handle duration menu
public int DurationMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    
    if (StrEqual(info, "Option_10seconds")) {
      curDuration = 10.0;
    }
    else if (StrEqual(info, "Option_20seconds")) {
      curDuration = 20.0;
    }
    else if (StrEqual(info, "Option_30seconds")) {
      curDuration = 30.0;
    }
    else if (StrEqual(info, "Option_40seconds")) {
      curDuration = 40.0;
    }
    else if (StrEqual(info, "Option_50seconds")) {
      curDuration = 50.0;
    }
    else if (StrEqual(info, "Option_60seconds")) {
      curDuration = 60.0;
    }
    
    //Go back to main menu again
    DisplayMenuAtItem(DrawMenu, client, 0, 0);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
  }
}

//Handle game tools menu
public int GameMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    
    if (StrEqual(info, "Option_Slap")) {
      //Slap Prisoners
      for (int i = 1; i <= MaxClients ; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          if (GetClientTeam(i) == CS_TEAM_T) {
            SlapPlayer(i, 0, true);
          }
        }
      }
      
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Gamemode - Slap");
      DisplayMenuAtItem(GameMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_Freezebomb")) {
      //Freezebomb Prisoners
      shouldFreezeT = !shouldFreezeT;
      ServerCommand("sm_freezebomb @t"); //Toggle freezebomb status
      
      if (shouldFreezeT == false) {
        //We stopped an already running timer
        if (freezeTimer != null) {
          KillTimer(freezeTimer);
          freezeTimer = null;
        }
      }
      else {
        freezeTimer = CreateTimer(GetConVarFloat(FindConVar("sm_freeze_duration")) + 0.5, Timer_ReportFreezebombResults);
      }
      
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Gamemode - Freezebomb");
      DisplayMenuAtItem(GameMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_Blind")) {
      shouldBlindT = !shouldBlindT; //toggle command
      
      for (int i = 1; i <= MaxClients ; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          if (GetClientTeam(i) == CS_TEAM_T) {
             if (shouldBlindT) {
               isBlind[i] = true;
               
               Handle fadePack;
               CreateDataTimer(0.0, FadeClient, fadePack);
               WritePackCell(fadePack, i);
               WritePackCell(fadePack, 0);
               WritePackCell(fadePack, 0);
               WritePackCell(fadePack, 0);
               WritePackCell(fadePack, 255);
             }
             else {
               isBlind[i] = false;
               
               Handle fadePack;
               CreateDataTimer(0.0, UnfadeClient, fadePack);
               WritePackCell(fadePack, i);
               WritePackCell(fadePack, 0);
               WritePackCell(fadePack, 0);
               WritePackCell(fadePack, 0);
               WritePackCell(fadePack, 0);
             }
          }
        }
      }

      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Gamemode - Blind");
      DisplayMenuAtItem(GameMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_CTShark")) {
      //Create menu
      Menu SharkMenu = CreateMenu(SharkMenuHandler);
      SetMenuExitBackButton(SharkMenu, true);
      SetMenuTitle(SharkMenu, "Select a shark");

      char sName[MAX_NAME_LENGTH], sUserId[10];
      
      for (int i = 1; i <= MaxClients ; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          if (GetClientTeam(i) == CS_TEAM_CT) {
            if (!isShark[i]) { //Don't add current sharks
              GetClientName(i, sName, sizeof(sName));
              IntToString(GetClientUserId(i), sUserId, sizeof(sUserId));
              AddMenuItem(SharkMenu, sUserId, sName);
            }
          }
        }
      }
      
      DisplayMenu(SharkMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_HighlightedDM")) {
      //Highlighted Team DM
      if (isInHighlightTeamDM) {
        //Already in team DM, turn off friendly fire
        turnOffTeamDM();
        
        DisplayMenuAtItem(GameMenu, client, 0, 0);
        return;
      }
      
      //Check if at least two teams exist
      int teamsLeft = getTeamDMNumTeamsAlive_TOnly();
      
      //Check if we can continue
      if (teamsLeft < 2) {
        DisplayMenuAtItem(GameMenu, client, 0, 0);
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Not Enough Teams", 2);
        return;
      }
      
      //Otherwise, turn on Team DM
      turnOnTeamDM();
      
      DisplayMenuAtItem(GameMenu, client, 0, 0);
    }
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(MainMenu, client, 0, 0);
    }
  }
}

//Handle draw tools menu
public int DrawMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    
    if (StrEqual(info, "Option_SpawnBeam")) {
      //Spawn beam
      PlaceBeam(client);
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_SetColour")) {
      //Create menu
      Menu SetColourMenu = CreateMenu(SetColourMenuHandler);
      SetMenuExitBackButton(SetColourMenu, true);
      SetMenuTitle(SetColourMenu, "Select Beam Colour");

      //Add menu items
      AddMenuItem(SetColourMenu, "Option_ColourRed", "Red");
      AddMenuItem(SetColourMenu, "Option_ColourGreen", "Green");
      AddMenuItem(SetColourMenu, "Option_ColourBlue", "Blue");
      AddMenuItem(SetColourMenu, "Option_ColourPurple", "Purple");
      AddMenuItem(SetColourMenu, "Option_ColourYellow", "Yellow");
      AddMenuItem(SetColourMenu, "Option_ColourCyan", "Cyan");
      AddMenuItem(SetColourMenu, "Option_ColourPink", "Pink");
      AddMenuItem(SetColourMenu, "Option_ColourOrange", "Orange");
      AddMenuItem(SetColourMenu, "Option_ColourBlack", "Black");
      AddMenuItem(SetColourMenu, "Option_ColourWhite", "White");
      
      DisplayMenu(SetColourMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_BeamDuration")) {
      //Create menu
      Menu DurationMenu = CreateMenu(DurationMenuHandler);
      SetMenuExitBackButton(DurationMenu, true);
      SetMenuTitle(DurationMenu, "Select Beam Display Time");

      //Add menu items
      AddMenuItem(DurationMenu, "Option_10seconds", "Last 10 seconds");
      AddMenuItem(DurationMenu, "Option_20seconds", "Last 20 seconds");
      AddMenuItem(DurationMenu, "Option_30seconds", "Last 30 seconds");
      AddMenuItem(DurationMenu, "Option_40seconds", "Last 40 seconds");
      AddMenuItem(DurationMenu, "Option_50seconds", "Last 50 seconds");
      AddMenuItem(DurationMenu, "Option_60seconds", "Last 60 seconds");

      DisplayMenu(DurationMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_Laser")) {

      //Toggle Laser
      if (LaserEnabled[client])
        RemoveLaserAction(client, 0);
      else
        PlaceLaserAction(client, 0);
      
      //Go back to draw tools menu again
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_Highlight")) {
      if (isInHighlightTeamDM) {
        DisplayMenuAtItem(DrawMenu, client, 0, 0);
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Can't Highlight");
        return;
      }
      
      //Get position client is looking at
      float hOrigin[3];
      GetAimOrigin(client, hOrigin, 2);
      
      //Iterate through all T's
      int playerToToggleHighlight = -1;
      float minDistance = 999999.9;
      
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          if (GetClientTeam(i) == CS_TEAM_T) {
            //Get player position
            float prisonerOrigin[3];
            GetClientAbsOrigin(i, prisonerOrigin);
            
            //Get position to hOrigin
            if (GetVectorDistance(prisonerOrigin, hOrigin, false) < minDistance) {
              minDistance = GetVectorDistance(prisonerOrigin, hOrigin, false);
              playerToToggleHighlight = i;
            }
          }
        }
      }
      
      //Highlight said player
      if (playerToToggleHighlight == -1 || minDistance > 100.0) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Highlight - No Player Found");
      }
      else {
        isHighlighted[playerToToggleHighlight] = !isHighlighted[playerToToggleHighlight];
        
        if (isHighlighted[playerToToggleHighlight]) {
          SetEntityRenderColor(playerToToggleHighlight, currentColour[0], currentColour[1], currentColour[2], 255);
          highlightedColour[playerToToggleHighlight] = currentColourCode;
        }
        else {
          SetEntityRenderColor(playerToToggleHighlight, 255, 255, 255, 255);
          highlightedColour[playerToToggleHighlight] = COLOUR_DEFAULT;
        }
      }
      
      //Go back to draw tools menu again
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
    else if (StrEqual(info, "Option_ClearHighlight")) {
      if (isInHighlightTeamDM) {
        DisplayMenuAtItem(DrawMenu, client, 0, 0);
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Can't Highlight");
        return;
      }
      
      //Iterate through all T's
      for (int i = 1; i <= MaxClients ; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          if (GetClientTeam(i) == CS_TEAM_T) {
            isHighlighted[i] = false;
            highlightedColour[i] = COLOUR_DEFAULT;
            SetEntityRenderColor(i, 255, 255, 255, 255);
          }
        }
      }
      
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Highlight - Removed from all", client);
      
      //Go back to draw tools menu again
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(MainMenu, client, 0, 0);
    }
  }
}

//Handle special days menu
public int SpecialDaysMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    //Check time in which special day was used
    if (GetTimeSinceRoundStart() >= GetConVarInt(cvar_specialday_starttime)) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Too Late", GetConVarInt(cvar_specialday_starttime));
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    
    if (StrEqual(info, "Option_Freeday")) {
      //Freeday
      setSpecialDay(SPECIALDAY_FREEDAY);
      
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Freeday");
    }
    else if (StrEqual(info, "Option_RoundModifiers")) {
      //Round modifiers
      //Create menu
      Menu RoundModifierMenu = CreateMenu(RoundModifierMenuHandler);
      SetMenuExitBackButton(RoundModifierMenu, true);
      SetMenuTitle(RoundModifierMenu, "Select a Round Modifier");
      
      //Add menu items
      AddMenuItem(RoundModifierMenu, "Option_RoundModifiers_LowGrav", "Low Gravity");
      AddMenuItem(RoundModifierMenu, "Option_RoundModifiers_FastSpeed", "Fast Speed");
      AddMenuItem(RoundModifierMenu, "Option_RoundModifiers_WalkOnly", "Walking Only");
      
      DisplayMenu(RoundModifierMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "Option_HNS")) {
      //Hide and Seek
      setSpecialDay(SPECIALDAY_HNS);
      
      //Set players health
      for (int i = 1; i <= MaxClients ; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          if (GetClientTeam(i) == CS_TEAM_CT) {
            SetEntProp(i, Prop_Data, "m_iHealth", GetConVarInt(cvar_hns_cthealth));
            
            //Blind CT's during hide time
            Handle fadePack;
            CreateDataTimer(0.0, FadeClient, fadePack);
            WritePackCell(fadePack, i);
            WritePackCell(fadePack, 0);
            WritePackCell(fadePack, 0);
            WritePackCell(fadePack, 0);
            WritePackCell(fadePack, 255);
            
            //Unblind after freeze time
            Handle fadePack2;
            CreateDataTimer(GetConVarFloat(cvar_hns_ctfreezetime), UnfadeClient, fadePack2);
            WritePackCell(fadePack2, i);
            WritePackCell(fadePack2, 0);
            WritePackCell(fadePack2, 0);
            WritePackCell(fadePack2, 0);
            WritePackCell(fadePack2, 0);
          }
          else if (GetClientTeam(i) == CS_TEAM_T) {
            SetEntProp(i, Prop_Data, "m_iHealth", GetConVarInt(cvar_hns_thealth));
          }
        }
      }
      
      //Remove radar
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          RemoveRadar(i);
        }
      }
      
      //Freeze CT's
      ServerCommand("sm_freeze @ct %d", GetConVarInt(cvar_hns_ctfreezetime));

      //Print start message
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - HNS", GetConVarInt(cvar_hns_ctfreezetime), RoundToNearest(GetConVarFloat(cvar_hns_tptime)));

      //Create timer to kill CT's if they lose
      hnsPrisonersWinHandle = CreateTimer(GetConVarFloat(cvar_hns_hiderswintime) - GetTimeSinceRoundStart(), Timer_HNSPrisonersWin);
      
      //Create timer for damage protection
      specialDayDamageProtection = true;
      damageProtectionHandle = CreateTimer(float(GetConVarInt(cvar_hns_ctfreezetime)) - GetConVarFloat(cvar_hns_tptime), SpecialDay_DamageProtection_End);

      //Teleport all players to warden beam
      TeleportPlayersToWarden(client, GetConVarFloat(cvar_hns_tptime), "hide and seek day", Teleport_Start_T, TELEPORTTYPE_T);
    }
    else if (StrEqual(info, "Option_Warday")) {
      //Warday
      setSpecialDay(SPECIALDAY_WARDAY);
      
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Warday", RoundToNearest(GetConVarFloat(cvar_warday_tptime)));
      
      //Create timer for damage protection
      specialDayDamageProtection = true;
      damageProtectionHandle = CreateTimer(GetConVarFloat(cvar_warday_tptime), SpecialDay_DamageProtection_End);
      
      //Teleport all players to warden beam
      TeleportPlayersToWarden(client, GetConVarFloat(cvar_warday_tptime), "warday", Teleport_Start_T, TELEPORTTYPE_T);
    }
    else if (StrEqual(info, "Option_VirusDay")) {
      //Check that we have 3 people total alive
      int numAlive = 0;
      
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
            ++numAlive;
          }
        }
      }
      
      //Check for enough people
      if (numAlive < 3) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - More People Needed", 3);
        return;
      }
      
      setSpecialDay(SPECIALDAY_VIRUSDAY);
      
      //Remove radar
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          RemoveRadar(i);
        }
      }
      
      //Create timer to kill infected if they lose
      virusdayNonInfectedWinHandle = CreateTimer(GetConVarFloat(cvar_virusday_noninfectedwintime) - GetTimeSinceRoundStart(), Timer_VirusDayInfectedWin);
      
      //Turn on friendly fire to prevent early round ends
      SetConVarBool(FindConVar("mp_friendlyfire"), true);
      SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);
      
      //Virus Day
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Virus Day", RoundToNearest(GetConVarFloat(cvar_virusday_tptime)), RoundToNearest(GetConVarFloat(cvar_virusday_hidetime)));
      
      //Create timer for infection start
      infectionStartTimer = CreateTimer(GetConVarFloat(cvar_virusday_tptime) + GetConVarFloat(cvar_virusday_hidetime), VirusDay_StartInfection);
      
      //Is in hide time
      isInInfectedHideTime = true;
      
      //Teleport all players to warden beam
      TeleportPlayersToWarden(client, GetConVarFloat(cvar_virusday_tptime), "Zombie Day", Teleport_Start_All, TELEPORTTYPE_ALL);
    }
    else if (StrEqual(info, "Option_FFADM")) {
      setSpecialDay(SPECIALDAY_FFADM);
      
      //Remove radar
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          RemoveRadar(i);
        }
      }
      
      //Create timer to slay all players
      freeforallRoundEndHandle = CreateTimer(GetConVarFloat(cvar_ffadm_slaytime) - GetTimeSinceRoundStart(), Timer_FFADMRoundEnds);
      
      //Turn on friendly fire for FFA
      SetConVarBool(FindConVar("mp_friendlyfire"), true);
      SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);
      
      //Create timer for damage protection
      specialDayDamageProtection = true;
      damageProtectionHandle = CreateTimer(GetConVarFloat(cvar_ffadm_tptime) + GetConVarFloat(cvar_ffadm_hidetime), SpecialDay_DamageProtection_End);
      
      //Create Timer for auto beacons
      autoBeaconHandle = CreateTimer(GetConVarFloat(cvar_ffadm_autobeacontime) - GetTimeSinceRoundStart(), Timer_AutoBeaconOn); 
      
      //FFADM Day message
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - FFADM Day", RoundToNearest(GetConVarFloat(cvar_ffadm_tptime)), RoundToNearest(GetConVarFloat(cvar_ffadm_hidetime)));
      
      //Create timer for ffa dm start
      freeforallStartTimer = CreateTimer(GetConVarFloat(cvar_ffadm_tptime) + GetConVarFloat(cvar_ffadm_hidetime), FFADM_Start);
      
      //Teleport all players to warden beam
      TeleportPlayersToWarden(client, GetConVarFloat(cvar_ffadm_tptime), "FFA Deathmatch", Teleport_Start_All, TELEPORTTYPE_ALL);
    }
    else if (StrEqual(info, "Option_TeamDM")) {
      //Check that we have 4 people total alive
      int numAlive = 0;
      
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
            ++numAlive;
          }
        }
      }
      
      //Check for enough people
      if (numAlive < 4) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - More People Needed", 4);
        return;
      }
      
      setSpecialDay(SPECIALDAY_TEAMDM);
      
      //Remove radar
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          RemoveRadar(i);
        }
      }
      
      //Create timer to slay all players
      freeforallRoundEndHandle = CreateTimer(GetConVarFloat(cvar_teamdm_slaytime) - GetTimeSinceRoundStart(), Timer_TeamDMRoundEnds);
      
      //Turn on friendly fire to prevent early round ends
      SetConVarBool(FindConVar("mp_friendlyfire"), true);
      SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);
      
      //Create timer for damage protection
      specialDayDamageProtection = true;
      damageProtectionHandle = CreateTimer(GetConVarFloat(cvar_teamdm_tptime) + GetConVarFloat(cvar_teamdm_hidetime), SpecialDay_DamageProtection_End);
      
      //Create Timer for auto beacons
      autoBeaconHandle = CreateTimer(GetConVarFloat(cvar_teamdm_autobeacontime) - GetTimeSinceRoundStart(), Timer_AutoBeaconOn);
      
      //Team Deathmatch Day message
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Day", RoundToNearest(GetConVarFloat(cvar_teamdm_tptime)), RoundToNearest(GetConVarFloat(cvar_teamdm_hidetime)));
      
      //Create timer for team dm start
      freeforallStartTimer = CreateTimer(GetConVarFloat(cvar_teamdm_tptime) + GetConVarFloat(cvar_teamdm_hidetime), TeamDM_Start);
      
      //Teleport all players to warden beam
      TeleportPlayersToWarden(client, GetConVarFloat(cvar_teamdm_tptime), "Team Deathmatch", Teleport_Start_All, TELEPORTTYPE_ALL);
    }
    else if (StrEqual(info, "Option_HungerGamesDay")) {
      setSpecialDay(SPECIALDAY_HUNGERGAMES);
      
      //Remove radar
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          RemoveRadar(i);
        }
      }
      
      //Create timer to slay all players
      freeforallRoundEndHandle = CreateTimer(GetConVarFloat(cvar_hungergames_slaytime) - GetTimeSinceRoundStart(), Timer_HungerGamesRoundEnds);
      
      //Turn on friendly fire for FFA
      SetConVarBool(FindConVar("mp_friendlyfire"), true);
      SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);
      
      //Create timer for damage protection
      specialDayDamageProtection = true;
      damageProtectionHandle = CreateTimer(GetConVarFloat(cvar_hungergames_tptime) + GetConVarFloat(cvar_hungergames_hidetime), SpecialDay_DamageProtection_End);
      
      //Create Timer for auto beacons
      autoBeaconHandle = CreateTimer(GetConVarFloat(cvar_hungergames_autobeacontime) - GetTimeSinceRoundStart(), Timer_AutoBeaconOn);
      
      //Strip all weapons
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          //Strip all current weapons from client and give them a knife
          StripWeapons(i);
          GivePlayerItem(i, "weapon_knife");
        }
      }
      
      //Hunger Games Day message
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Hunger Games Day", RoundToNearest(GetConVarFloat(cvar_hungergames_tptime)), RoundToNearest(GetConVarFloat(cvar_hungergames_hidetime)));
      
      //Create timer for start
      freeforallStartTimer = CreateTimer(GetConVarFloat(cvar_hungergames_tptime) + GetConVarFloat(cvar_hungergames_hidetime), HungerGames_Start);
      
      //Teleport all players to warden beam
      TeleportPlayersToWarden(client, GetConVarFloat(cvar_hungergames_tptime), "Hunger Games", Teleport_Start_All, TELEPORTTYPE_ALL);
    }
    
    else if (StrEqual(info, "Option_CustomDay")) {
      //Custom day
      setSpecialDay(SPECIALDAY_CUSTOM);
      
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Custom");
    }
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(MainMenu, client, 0, 0);
    }
  }
}

//Handle round modifier menu
public int RoundModifierMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    //Check time in which special day was used
    if (GetTimeSinceRoundStart() >= GetConVarInt(cvar_specialday_starttime)) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Too Late", GetConVarInt(cvar_specialday_starttime));
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    if (StrEqual(info, "Option_RoundModifiers_LowGrav")) {
      roundModifier = ROUNDMODIFIER_LOWGRAVITY;
    
      //Set Low Gravity
      ConVar cvar_grav = FindConVar("sv_gravity");
      orig_sv_gravity = GetConVarInt(cvar_grav);
      SetConVarInt(cvar_grav, GetConVarInt(cvar_roundmodifier_lowgravity));
      
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Round Modifier Set", "Low Gravity");
    }
    else if (StrEqual(info, "Option_RoundModifiers_FastSpeed")) {
      roundModifier = ROUNDMODIFIER_FASTSPEED;
      
      //Set fast speed
      for (int i = 1; i <= MaxClients; ++i) {
        if (IsClientInGame(i) && IsPlayerAlive(i)) {
          SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", GetConVarFloat(cvar_roundmodifier_fastspeed));
          SetEntityGravity(i, GetConVarFloat(cvar_roundmodifier_fastspeed_gravity));
        }
      }
      
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Round Modifier Set", "Fast Speed");
    }
    else if (StrEqual(info, "Option_RoundModifiers_WalkOnly")) {
      roundModifier = ROUNDMODIFIER_WALKINGONLY;
      
      //Set Max Speed
      ConVar cvar_maxspeed = FindConVar("sv_maxspeed");
      orig_sv_maxspeed = GetConVarInt(cvar_maxspeed);
      SetConVarInt(cvar_maxspeed, GetConVarInt(cvar_roundmodifier_walkingonly_maxspeed));
      
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Round Modifier Set", "Walking Only");
    }
      
    //Set special day
    setSpecialDay(SPECIALDAY_ROUNDMODIFIER);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(SpecialDaysMenu, client, 0, 0);
    }
  }
}

//Handle colour menu
public int SetColourMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    
    if (StrEqual(info, "Option_ColourRed")) {
      //Red
      currentColour = redColour;
      currentColourCode = COLOUR_RED;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "darkred", "red");
    }
    else if (StrEqual(info, "Option_ColourGreen")) {
      //Green
      currentColour = greenColour;
      currentColourCode = COLOUR_GREEN;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "lightgreen", "green");
    }
    else if (StrEqual(info, "Option_ColourBlue")) {
      //Blue
      currentColour = blueColour;
      currentColourCode = COLOUR_BLUE;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "blue", "blue");
    }
    else if (StrEqual(info, "Option_ColourPurple")) {
      //Purple
      currentColour = purpleColour;
      currentColourCode = COLOUR_PURPLE;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "purple", "purple");
    }
    else if (StrEqual(info, "Option_ColourYellow")) {
      //Yellow
      currentColour = yellowColour;
      currentColourCode = COLOUR_YELLOW;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "olive", "yellow");
    }
    else if (StrEqual(info, "Option_ColourCyan")) {
      //Cyan
      currentColour = cyanColour;
      currentColourCode= COLOUR_CYAN;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "lightblue", "cyan");
    }
    else if (StrEqual(info, "Option_ColourPink")) {
      //Pink
      currentColour = pinkColour;
      currentColourCode = COLOUR_PINK;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "pink");
    }
    else if (StrEqual(info, "Option_ColourOrange")) {
      //Orange
      currentColour = orangeColour;
      currentColourCode = COLOUR_ORANGE;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "orange");
    }
    else if (StrEqual(info, "Option_ColourWhite")) {
      //White
      currentColour = whiteColour;
      currentColourCode = COLOUR_WHITE;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "white");
    }
    else if (StrEqual(info, "Option_ColourBlack")) {
      //Black
      currentColour = blackColour;
      currentColourCode = COLOUR_BLACK;
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Colour Active", "default", "black");
    }
    
    //Go back to draw menu again
    DisplayMenuAtItem(DrawMenu, client, 0, 0);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(DrawMenu, client, 0, 0);
    }
  }
}

//Handle shark menu
public int SharkMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
  if (action == MenuAction_Select)
  {
    //Ensure user is warden
    bool isWarden = view_as<bool>(warden_iswarden(client));
    
    if (!isWarden) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
      return;
    }
    
    char info[32];
    GetMenuItem(menu, param2, info, sizeof(info));
    int target = GetClientOfUserId(StringToInt(info));
    
    isShark[target] = true;
    
    //Save current health
    int targetCurrentHP = GetEntProp(target, Prop_Send, "m_iHealth");
    int targetCurrentArmour = GetEntProp(target, Prop_Send, "m_ArmorValue");
    
    //Set sharks HP to high ammount
    SetEntProp(target, Prop_Data, "m_iHealth", GetConVarInt(cvar_shark_health));
    SetEntProp(target, Prop_Data, "m_ArmorValue", 0);
    
    //Blind the shark
    Handle fadePack;
    CreateDataTimer(0.0, FadeClient, fadePack);
    WritePackCell(fadePack, target);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 255);

    //Set timer to play shark sound
    CreateTimer(5.0, Timer_SharkSound, target);
    
    //Set end timer to remove shark
    CreateTimer(GetConVarFloat(cvar_shark_duration), Timer_RemoveShark, target);
    
    //Set end timer for hp
    Handle pack;
    CreateDataTimer(GetConVarFloat(cvar_shark_duration) + 5.0, Timer_RemoveShark_HP, pack);
    WritePackCell(pack, target);
    WritePackCell(pack, targetCurrentHP);
    WritePackCell(pack, targetCurrentArmour);

    //Set warning timer
    CreateTimer(GetConVarFloat(cvar_shark_duration) - GetConVarFloat(cvar_shark_timeleft_warning), Timer_WarningShark, target);
    
    //Print Message
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Shark New", target, RoundToNearest(GetConVarFloat(cvar_shark_duration)));
    
    //Go back to game menu again
    DisplayMenuAtItem(GameMenu, client, 0, 0);
  }
  else if (action == MenuAction_Cancel)
  {
    if (param2 == MenuCancel_ExitBack) {
      //Goto parent menu
      DisplayMenuAtItem(GameMenu, client, 0, 0);
    }
  }
}

/*********************************
 * Timers
 ********************************/

//Quick place beams using bind
public Action PlaceBeamAction(int client, int args)
{
  PlaceBeam(client);
}

void PlaceBeam(int client)
{
  //Ensure team is CT
  if (GetClientTeam(client) != CS_TEAM_CT) { 
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "CT Only Command");
    return;
  }
  
  //Ensure user is warden
  bool isWarden = view_as<bool>(warden_iswarden(client));
  
  if (!isWarden) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
    return;
  }
  
  //Ensure max number of beams haven't already been made
  if (currentBeamsUsed >= GetConVarInt(cvar_maxbeams)) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Too Many Beams");
    return;
  }
  
  //Get position client is looking at
  float hOrigin[3];
  GetAimOrigin(client, hOrigin, 1);
  
  float clientOrigin[3];
  GetClientAbsOrigin(client, clientOrigin);
  
  hOrigin[2] += 10; //move beam Y slightly above ground
  
  //Ensure beam is not too far
  if (GetVectorDistance(clientOrigin, hOrigin, false) > GetConVarInt(cvar_maxunits)) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Beam Too Far");
    return;
  }
  
  //Check durations
  int excessDurationCount = RoundToFloor(curDuration / 10.0);
  --excessDurationCount;
  
  if (excessDurationCount != 0) {
    //Start timer to recreate beacon
    Handle pack;
    CreateDataTimer(10.0, ExcessBeamSpawner, pack);
    WritePackCell(pack, excessDurationCount);
    
    //Origin
    WritePackFloat(pack, hOrigin[0]);
    WritePackFloat(pack, hOrigin[1]);
    WritePackFloat(pack, hOrigin[2]);
    
    //RGB Colour
    WritePackCell(pack, currentColour[0]);
    WritePackCell(pack, currentColour[1]);
    WritePackCell(pack, currentColour[2]);
    WritePackCell(pack, currentColour[3]);
  }

  
  //Draw Beam
  TE_SetupBeamRingPoint(hOrigin, 75.0, 75.5, g_BeamSprite, g_HaloSprite, 0, 0, 10.0, 10.0, 0.0, currentColour, 0, 0);
  TE_SendToAll();
  
  ++currentBeamsUsed;
  CreateTimer(curDuration, BeamCounterResetTimer);
  
  return;
}

public Action ExcessBeamSpawner(Handle timer, Handle pack)
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
  TE_SetupBeamRingPoint(hOrigin, 75.0, 75.5, g_BeamSprite, g_HaloSprite, 0, 0, 10.0, 10.0, 0.0, beamColour, 0, 0);
  TE_SendToAll();
  
  //Restart next timer
  --excessDurationCount;
  
  if (excessDurationCount != 0) {
    Handle nextPack;
    CreateDataTimer(10.0, ExcessBeamSpawner, nextPack);
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

//Reset beam counter for 1 beam
public Action BeamCounterResetTimer(Handle timer)
{
  --currentBeamsUsed;
}

//Teleport start timer handler
public Action Teleport_Start_T(Handle timer, Handle pack)
{
  ResetPack(pack);
  char buffer[128];
  ReadPackString(pack, buffer, sizeof(buffer));
  
  float hOrigin[3], hAngles[3];
  hOrigin[0] = ReadPackFloat(pack);
  hOrigin[1] = ReadPackFloat(pack);
  hOrigin[2] = ReadPackFloat(pack);
  
  hAngles[0] = ReadPackFloat(pack);
  hAngles[1] = ReadPackFloat(pack);
  hAngles[2] = ReadPackFloat(pack);
  
  //Teleport all T's to location
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T) {
        TeleportEntity(i, hOrigin, hAngles, NULL_VECTOR);
      }
    }
  }
  
  //Report Teleported
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Teleport Start T", buffer);
  
  teleportHandle = null;
}

//Teleport start timer handler
public Action Teleport_Start_All(Handle timer, Handle pack)
{
  ResetPack(pack);
  char buffer[128];
  ReadPackString(pack, buffer, sizeof(buffer));
  
  float hOrigin[3], hAngles[3];
  hOrigin[0] = ReadPackFloat(pack);
  hOrigin[1] = ReadPackFloat(pack);
  hOrigin[2] = ReadPackFloat(pack);
  
  hAngles[0] = ReadPackFloat(pack);
  hAngles[1] = ReadPackFloat(pack);
  hAngles[2] = ReadPackFloat(pack);
  
  //Teleport all players to location
      
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        TeleportEntity(i, hOrigin, hAngles, NULL_VECTOR);
      }
    }
  }
  
  //Report Teleported
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Teleport Start All", buffer);
  
  teleportHandle = null;
}

public Action Timer_RemoveShark(Handle timer, int target)
{
  if (!isShark[target])
    return;
  
  //Unblind them
  Handle fadePack;
  CreateDataTimer(0.0, UnfadeClient, fadePack);
  WritePackCell(fadePack, target);
  WritePackCell(fadePack, 0);
  WritePackCell(fadePack, 0);
  WritePackCell(fadePack, 0);
  WritePackCell(fadePack, 0);
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Shark Removed", target);
}

public Action Timer_RemoveShark_HP(Handle timer, Handle pack)
{
  ResetPack(pack);
  
  int target = ReadPackCell(pack);
  int origHP = ReadPackCell(pack);
  int origArmour = ReadPackCell(pack);

  if (!isShark[target])
    return;
    
  isShark[target] = false;
  
  //Reset CT health/armour
  SetEntProp(target, Prop_Data, "m_iHealth", origHP);
  SetEntProp(target, Prop_Data, "m_ArmorValue", origArmour);
}

//Play shark sound for the shark
public Action Timer_SharkSound(Handle timer, int target)
{
  if (!isShark[target])
    return;
    
  EmitSoundToAllAny(JAWS_SOUND, target, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN); 
}

//Reset beam counter for 1 beam
public Action Timer_WarningShark(Handle timer, int target)
{
  //Warn everybody Shark is about to unshark
  if (isShark[target])
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Shark Warning", target, RoundToNearest(GetConVarFloat(cvar_shark_timeleft_warning)));
}

//Laser code
public Action Timer_Check_Laser(Handle timer)
{
  float pos[3];
  int colour = GetRandomInt(0,6);
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && LaserEnabled[i]) {
      TraceEye(i, pos);
      if (GetVectorDistance(pos, LastLaser[i]) > 6.0) {
        LaserP(LastLaser[i], pos, g_DefaultColors_c[colour]);
        LastLaser[i][0] = pos[0];
        LastLaser[i][1] = pos[1];
        LastLaser[i][2] = pos[2];
      }
    } 
  }
}

//Report Freezebomb results
public Action Timer_ReportFreezebombResults(Handle timer)
{
  //Check to see if timer should be stopped
  if (!shouldFreezeT) {
    return Plugin_Handled;
  }
  
  //Report results
  int highestClient = -1;
  int lowestClient = -1;
  float highestCord = -999999.0;
  float lowestCord = 999999.0;
      
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T) {
        float player_vec[3];
        GetClientAbsOrigin(i, player_vec);
        
        if (player_vec[2] > highestCord) {
          highestCord = player_vec[2];
          highestClient = i;
        }
        
        if (player_vec[2] < lowestCord) {
          lowestCord = player_vec[2];
          lowestClient = i;
        }
        
      }
    }
  }

  if (highestClient != -1) 
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Highest Freezebomb", highestClient);
  
  if (lowestClient != -1)
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Lowest Freezebomb", lowestClient);
  
  //Disable freeze bool
  shouldFreezeT = false;
  
  return Plugin_Handled;
}

//Finish MicCheck
public Action Timer_MicCheckFinish(Handle timer)
{
  isInMicCheckTime = false;
  int numGuardsMoved = 0;
  
  for (int i = 0; i < GetArraySize(micSwapTargets); ++i) {
    int client = GetArrayCell(micSwapTargets, i);
    if (IsClientInGame(client)) {
      if (GetClientTeam(client) == CS_TEAM_CT) {
        //Twap clients team
        ChangeClientTeam(client, CS_TEAM_T);
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Miccheck You Were Swapped");
        ++numGuardsMoved;
      }
    }
  }
  
  //Miccheck finished
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Miccheck Finished", numGuardsMoved);
  
  ClearArray(micSwapTargets);
}

//Check gaurd mic
public Action Timer_MicCheck(Handle timer, int client)
{
  if (!isInMicCheckTime)
    return Plugin_Handled;
  
  if (IsClientInGame(client) && IsPlayerAlive(client)) {
    if (GetClientTeam(client) == CS_TEAM_CT) {
      if (IsClientSpeaking(client)) {
        PrintHintText(client, "%t", "Miccheck Status Verified");
        RemoveFromArray(micSwapTargets, FindValueInArray(micSwapTargets, client)); //remove this verified client from the array
      } else {
        PrintHintText(client, "%t", "Miccheck Status Not Verified");
        CreateTimer(0.5, Timer_MicCheck, client);
      }
    }
  }

  return Plugin_Handled;
}

//Called when prisoners win HNS day
public Action Timer_HNSPrisonersWin(Handle timer)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_CT) {
        ForcePlayerSuicide(i);
      }
    }
  }
  
  //Print victory message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - HNS Prisoners Win");
  
  //Reset timer handle
  hnsPrisonersWinHandle = null;
}

//Called when damage protection is to be turned off
public Action SpecialDay_DamageProtection_End(Handle timer)
{
  specialDayDamageProtection = false;
  damageProtectionHandle = null;
}

//Timer called once Virus day starts
public Action VirusDay_StartInfection(Handle timer)
{
  //Pick two people to infect
  int entryCount = 0;
  ArrayList eligblePlayers = CreateArray(MaxClients+1);
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        PushArrayCell(eligblePlayers, i);
        ++entryCount;
        setAndPreserveClanTag(i, "[NOT INFECTED]");
      }
    }
  }
  
  int totalToGive = 2;
  
  //Check to see if at least 'totalToGive' players are alive at this point and if not, abort
  if (entryCount < totalToGive) {
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Virus Day Aborted");
    infectionStartTimer = null; //Needed so invalid handle doesnt occur later in Reset_Vars()
    return Plugin_Handled;
  }
  
  int client1 = -1;
  int client2 = -1;
  
  for (int c = 0; c < totalToGive; ++c) {
    int rand = GetRandomInt(0, entryCount - 1);
    int client = GetArrayCell(eligblePlayers, rand);
    removeClientFromArray(eligblePlayers, client);
    entryCount = GetArraySize(eligblePlayers)
    
    if (client1 == -1)
      client1 = client;
    else if (client2 == -1)
      client2 = client;
    
    //Infect said client
    VirusDay_InfectClient(client, false);
  }
  
  isInInfectedHideTime = false;
  
  //Enable hud for all
  CreateTimer(0.5, Timer_VirusDayShowHud);
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Virus Day First Infected", client1, client2);
  
  infectionStartTimer = null;
  
  return Plugin_Handled;
}

//Called when non infected win virus day
public Action Timer_VirusDayInfectedWin(Handle timer)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (isInfected[i]) {
        //Burn the infected
        ServerCommand("sm_burn #%d 10000", GetClientUserId(i));
      }
    }
  }
  
  isPastCureFoundTime = true;
  
  //Disable medic
  Disable_Medics();
  
  //Start draining all infected
  drainTimer = CreateTimer(GetConVarFloat(cvar_virusday_drain_interval), Timer_DrainHP, _, TIMER_REPEAT);
  
  //Print victory message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Virus Day Non Infected Win");
  
  //Reset timer handle
  virusdayNonInfectedWinHandle = null;
}

public Action Timer_VirusDayShowHud(Handle timer)
{
  if (!specialDay || specialDay != SPECIALDAY_VIRUSDAY)
    return Plugin_Handled;
  
  int numDead = 0;
  int numInfected = 0;
  int numNotInfected = 0;
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i)) {
      if (!IsPlayerAlive(i))
        ++numDead;
      else {
        if (isInfected[i])
          ++numInfected;
        else
          ++numNotInfected;
      }
    }
  }
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i)) {
      char status[32];
      char statusColour[10];
      
      if (!IsPlayerAlive(i)) {
        Format(status, sizeof(status), "%s", "Dead");
        Format(statusColour, sizeof(statusColour), "%s", "#CCCCCC");
      }
      else {
        if (isInfected[i]) {
          Format(status, sizeof(status), "%s", "Infected");
          Format(statusColour, sizeof(statusColour), "%s", "#FF0033");
        }
        else {
          Format(status, sizeof(status), "%s", "Not Infected");
          Format(statusColour, sizeof(statusColour), "%s", "#336600");
        }
      }
      
      //Hint HUD
      PrintHintText(i, "%t", "SpecialDay - Virus Day HUD", statusColour, status, numInfected, numNotInfected);
    }
  }
  
  CreateTimer(0.5, Timer_VirusDayShowHud);

  return Plugin_Handled;
}

public Action Timer_DrainHP(Handle timer)
{
  //For each client
  for (new i = 1; i <= MaxClients; ++i)
  {
    //Check if player is truly alive
    if (IsClientInGame(i) && IsPlayerAlive(i) && isInfected[i]) {
      int currentHP = GetEntProp(i, Prop_Send, "m_iHealth");
      int drainAmount = GetRandomInt(GetConVarInt(cvar_virusday_min_drain), GetConVarInt(cvar_virusday_max_drain));
      
      //If player should die
      if (drainAmount > currentHP) {
        //Play death sound
        char infectDeathSounds[2][] = {INFECT_DEATH_SOUND_1, INFECT_DEATH_SOUND_2};
        int randNum = GetRandomInt(0, sizeof(infectDeathSounds) - 1);

        //Play explosion sounds
        EmitSoundToAllAny(infectDeathSounds[randNum], i, SNDCHAN_USER_BASE, SNDLEVEL_RAIDSIREN); 
        
        //Kill the player
        SetEntProp(i, Prop_Send, "m_ArmorValue", 0, 1);  //Set Armor to 0
        DealDamage(i, currentHP + 1, i, DMG_GENERIC, "");
      }
      //Othwerwise drain their HP
      else {
        SetEntityHealth(i, currentHP - drainAmount);
      }
    }
  }
}

//Called when FFADM round ends
public Action Timer_FFADMRoundEnds(Handle timer)
{
  //Set FFA to stalement so no winner is picked based on deaths
  isFFARoundStalemate = true;

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      ForcePlayerSuicide(i);
    }
  }
  
  //Print round end message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - FFADM Round Over");
  
  //Reset timer handle
  freeforallRoundEndHandle = null;
}

//Timer called once FFADM day starts
public Action FFADM_Start(Handle timer)
{
  //Give players full armour
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      GivePlayerItem( i, "item_assaultsuit");
      SetEntProp(i, Prop_Data, "m_ArmorValue", 100, 1);
    }
  }

  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - FFADM Started");
  
  freeforallStartTimer = null;
  
  return Plugin_Handled;
}

//Called when TeamDM round ends
public Action Timer_TeamDMRoundEnds(Handle timer)
{
  //Set FFA to stalement so no winner is picked based on deaths
  isFFARoundStalemate = true;

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      ForcePlayerSuicide(i);
    }
  }
  
  //Print round end message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Round Over");
  
  //Reset timer handle
  freeforallRoundEndHandle = null;
}

//Timer called once TeamDM day starts
public Action TeamDM_Start(Handle timer)
{
  //Check that there are enough players to play
  int entryCount = 0;
  ArrayList eligblePlayers = CreateArray(MaxClients+1);
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        PushArrayCell(eligblePlayers, i);
        ++entryCount;
      }
    }
  }
  
  //Check to see if the minimum number of players are present
  if (entryCount < 4) {
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Aborted");
    freeforallStartTimer = null; //Needed so invalid handle doesnt occur later in Reset_Vars()
    CS_TerminateRound(GetConVarFloat(FindConVar("mp_round_restart_delay")), CSRoundEnd_CTWin, false);
    return Plugin_Handled;
  }
  
  //Give players full armour
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      GivePlayerItem( i, "item_assaultsuit");
      SetEntProp(i, Prop_Data, "m_ArmorValue", 100, 1);
    }
  }

  //Pick teams and highlight players
  int numTeams = 0;
  
  if (entryCount <= 10)
    numTeams = 2;
  else if (entryCount <= 20)
    numTeams = 3;
  else if (entryCount <= 30)
    numTeams = 4;
  else if (entryCount <= 40)
    numTeams = 5;
  
  int teamColourCodes[5] = { COLOUR_RED, COLOUR_BLUE, COLOUR_GREEN, COLOUR_YELLOW, COLOUR_BLACK};
  int teamCounter = 0;
  int numAlive = entryCount;  //needed for loop
  
  //Assign team to each eligble player
  for (int c = 0; c < numAlive; ++c) {
    int rand = GetRandomInt(0, entryCount - 1);
    int client = GetArrayCell(eligblePlayers, rand);
    removeClientFromArray(eligblePlayers, client);
    entryCount = GetArraySize(eligblePlayers)
    
    //Here we have a random client, assign them to a random team
    isHighlighted[client] = true;
    highlightedColour[client] = teamColourCodes[teamCounter];
    
    //Highlight them and print a message
    char clantag[10];
    
    if (highlightedColour[client] == COLOUR_RED) {
      SetEntityRenderColor(client, redColour[0], redColour[1], redColour[2], 255);
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", numTeams, "darkred", "red");
      Format(clantag, sizeof(clantag), "[RED]");
    }
    else if (highlightedColour[client] == COLOUR_BLUE) {
      SetEntityRenderColor(client, blueColour[0], blueColour[1], blueColour[2], 255);
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", numTeams, "blue", "blue");
      Format(clantag, sizeof(clantag), "[BLUE]");
    }
    else if (highlightedColour[client] == COLOUR_GREEN) {
      SetEntityRenderColor(client, greenColour[0], greenColour[1], greenColour[2], 255);
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", numTeams, "lightgreen", "green");
      Format(clantag, sizeof(clantag), "[GREEN]");
    }
    else if (highlightedColour[client] == COLOUR_YELLOW) {
      SetEntityRenderColor(client, yellowColour[0], yellowColour[1], yellowColour[2], 255);
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", numTeams, "olive", "yellow");
      Format(clantag, sizeof(clantag), "[YELLOW]");
    }
    else if (highlightedColour[client] == COLOUR_BLACK) {
      SetEntityRenderColor(client, blackColour[0], blackColour[1], blackColour[2], 255);
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Team Deathmatch Started", numTeams, "default", "black");
      Format(clantag, sizeof(clantag), "[BLACK]");
    }
    
    //Set clan tag and preserve original clan tag
    setAndPreserveClanTag(client, clantag);
    
    ++teamCounter;
    
    //Reset counter if we reach last team
    if (teamCounter == numTeams)
      teamCounter = 0;
  }
  
  isPastHideTime = true; //hide time is over
  
  //Enable hud for all
  CreateTimer(0.5, Timer_TeamDMShowHud);
  
  freeforallStartTimer = null;
  
  return Plugin_Handled;
}

//Team DM HUD
public Action Timer_TeamDMShowHud(Handle timer)
{
  if (!specialDay || specialDay != SPECIALDAY_TEAMDM)
    return Plugin_Handled;
  
  for (int client = 1; client <= MaxClients; ++client) {
    if (IsClientInGame(client) && isHighlighted[client]) {
      int teammatesAlive = 0;
      int teammatesTotal = 0;
      int enemiesAlive = 0;
      int enemiesTotal = 0;
    
      //Get required info
      for (int j = 1; j <= MaxClients; ++j) {
        if (IsClientInGame(j) && isHighlighted[j]) {
          if (j == client)  //ignore client
            continue;
            
          if (highlightedColour[j] == highlightedColour[client]) {
            ++teammatesTotal;
            if (IsPlayerAlive(j))
              ++teammatesAlive;
          }
          else {
            ++enemiesTotal;
            if (IsPlayerAlive(j))
              ++enemiesAlive;
          }
        }
      }
      
      char team[10];
      char teamColour[10];
      
      if (highlightedColour[client] == COLOUR_RED) {
        Format(team, sizeof(team), "%s", "RED");
        Format(teamColour, sizeof(teamColour), "%s", "#FF0033");
      }
      else if (highlightedColour[client] == COLOUR_BLUE) {
        Format(team, sizeof(team), "%s", "BLUE");
        Format(teamColour, sizeof(teamColour), "%s", "#0000FF");
      }
      else if (highlightedColour[client] == COLOUR_GREEN) {
        Format(team, sizeof(team), "%s", "GREEN");
        Format(teamColour, sizeof(teamColour), "%s", "#336600");
      }
      else if (highlightedColour[client] == COLOUR_YELLOW) {
        Format(team, sizeof(team), "%s", "YELLOW");
        Format(teamColour, sizeof(teamColour), "%s", "#FFFF00");
      }
      else if (highlightedColour[client] == COLOUR_BLACK) {
        Format(team, sizeof(team), "%s", "BLACK");
        Format(teamColour, sizeof(teamColour), "%s", "#000000");
      }
      
      //Hint HUD
      PrintHintText(client, "%t", "SpecialDay - Team Deathmatch HUD", teamColour, team, teammatesAlive, teammatesTotal, enemiesAlive, enemiesTotal);
    }
  }
  
  CreateTimer(0.5, Timer_TeamDMShowHud);

  return Plugin_Handled;
}


//Called when hunger games round ends
public Action Timer_HungerGamesRoundEnds(Handle timer)
{
  //Set FFA to stalement so no winner is picked based on deaths
  isFFARoundStalemate = true;

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      ForcePlayerSuicide(i);
    }
  }
  
  //Print round end message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Hunger Games Round Over");
  
  //Reset timer handle
  freeforallRoundEndHandle = null;
}

//Timer called once hunger games start
public Action HungerGames_Start(Handle timer)
{
  //For each player, randomly give them: health, primary weapon, secondary weapon, and grenades
  char primaryWeapons[23][] = {"weapon_ak47","weapon_aug","weapon_awp","weapon_bizon","weapon_famas","weapon_g3sg1","weapon_galilar","weapon_m249","weapon_m4a1","weapon_m4a1_silencer","weapon_mac10","weapon_mag7","weapon_mp7","weapon_mp9","weapon_negev","weapon_nova","weapon_p90","weapon_sawedoff","weapon_scar20","weapon_sg556","weapon_ssg08","weapon_ump45","weapon_xm1014"};
  char secondaryWeapons[10][] = {"weapon_cz75a","weapon_deagle","weapon_fiveseven","weapon_elite","weapon_glock","weapon_hkp2000","weapon_p250","weapon_revolver","weapon_usp_silencer","weapon_tec9"};
  char grenades[6][] = {"weapon_decoy","weapon_flashbang","weapon_hegrenade","weapon_incgrenade","weapon_molotov","weapon_smokegrenade"};
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      //Strip all current weapons from client
      StripWeapons(i);
      
      //Give them knife
      GivePlayerItem(i, "weapon_knife");
      
      //Give player random health
      float randomHealth = GetRandomFloat(GetConVarFloat(cvar_hungergames_min_random_health), GetConVarFloat(cvar_hungergames_max_random_health));
      SetEntProp(i, Prop_Data, "m_iHealth", RoundToFloor(randomHealth));
      
      //Give player full armour
      GivePlayerItem( i, "item_assaultsuit");
      SetEntProp(i, Prop_Data, "m_ArmorValue", 100, 1);
      
      //Give player random primary
      int randNum = GetRandomInt(0, sizeof(primaryWeapons) - 1);
      GivePlayerItem(i, primaryWeapons[randNum]);
        
      //Give player random secondary
      randNum = GetRandomInt(0, sizeof(secondaryWeapons) - 1);
      GivePlayerItem(i, secondaryWeapons[randNum]);
      
      //Give player random grenades
      randNum = GetRandomInt(0, sizeof(grenades) - 1);
      GivePlayerItem(i, grenades[randNum]);
      
    }
  }

  isPastHideTime = true; //no longer hide time
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Hunger Games Started");
  
  freeforallStartTimer = null;
  
  return Plugin_Handled;
}

//Auto beacon all alive players
public Action Timer_AutoBeaconOn(Handle timer)
{
  ServerCommand("sm_beacon @alive");
  ServerCommand("sm_msay All players must now actively hunt other players.");
  autoBeaconHandle = null;
}

/*********************************
 *  Helper Functions
 *********************************/

//Reset all variables of importance
void Reset_Vars()
{
  //Close menu handler when round starts/ends
  if (MainMenu != null) delete MainMenu;
  if (GameMenu != null) delete GameMenu;
  if (DrawMenu != null) delete DrawMenu;
  if (SpecialDaysMenu != null) delete SpecialDaysMenu;
  if (hnsPrisonersWinHandle != null) delete hnsPrisonersWinHandle;
  if (teleportHandle != null) delete teleportHandle;
  if (damageProtectionHandle != null) delete damageProtectionHandle;
  if (virusdayNonInfectedWinHandle != null) delete virusdayNonInfectedWinHandle;
  if (drainTimer != null) delete drainTimer;
  if (infectionStartTimer != null) delete infectionStartTimer;
  if (freeforallRoundEndHandle != null) delete freeforallRoundEndHandle; 
  if (freeforallStartTimer != null) delete freeforallStartTimer;
  if (autoBeaconHandle != null) delete autoBeaconHandle;
  
  //Reset settings
  currentBeamsUsed = 0;
  curDuration = 20.0;
  shouldBlindT = false;
  shouldFreezeT = false;
  freezeTimer = null; 
  currentColour = redColour;
  currentColourCode = COLOUR_RED;
  specialDay = SPECIALDAY_NONE;
  roundModifier = ROUNDMODIFIER_NONE;
  micCheckConducted = false;
  isInMicCheckTime = false;
  isInHighlightTeamDM = false;
  specialDayDamageProtection = false;
  isInInfectedHideTime = false;
  isPastCureFoundTime = false;
  isFFARoundStalemate = false
  isPastHideTime = false;
  
  SetConVarInt(FindConVar("sv_gravity"), orig_sv_gravity);
  SetConVarInt(FindConVar("sv_maxspeed"), orig_sv_maxspeed);
  
  newRoundTimeElapsed = GetTime();
  
  ClearArray(micSwapTargets);
 
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
      
    //Remove enabled lasers for all
    RemoveLaserAction(i, 0);
    
    //Unblind all
    if (isBlind[i]) {
      Handle fadePack;
      CreateDataTimer(0.0, UnfadeClient, fadePack);
      WritePackCell(fadePack, i);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 0);
      
      isBlind[i] = false;
    }
    
    //Unhighlight
    if (isHighlighted[i] && IsClientInGame(i) && IsPlayerAlive(i)) {
      SetEntityRenderColor(i, 255, 255, 255, 255);
    }
    
    isHighlighted[i] = false;
    highlightedColour[i] = COLOUR_DEFAULT;
    
    //Reset shark
    isShark[i] = false;
    
    //Reset infected related things
    if (isInfected[i]) {
      //Icon
      SafeDelete(infectedIcon[i]);
      infectedIcon[i] = -1;
    }
    
    //Reset speed (for infected[i] as well as for round modifiers)
    SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);
    
    //Reset gravity
    SetEntityGravity(i, 1.0);
    
    //Reset overlays
    ShowOverlayToClient(i, "");
    
    //Reset infected
    isInfected[i] = false;
    
    //Reset clan tag to what was stored
    if (restoreClanTags) {
      CS_SetClientClanTag(i, clantagStorage[i]);
      clantagStorage[i] = ""; //reset storage
    }
  }
  
  //After all clan tags have been restored, disable bool
  restoreClanTags = false;
  
  //Disable Friendly Fire
  SetConVarBool(FindConVar("mp_friendlyfire"), false);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), false);
  
  //Disable priority speaker for new warden
  ConVar priorityToggle = FindConVar("sm_wardentalk2_enabled");
  
  if (priorityToggle != null) {
    SetConVarBool(priorityToggle, false);
  }
  
  //Enable LR if disabled
  ConVar hostiesLR = FindConVar("sm_hosties_lr");
  if (hostiesLR != null)
    SetConVarInt(hostiesLR, 1);  
    
  //Enable colouring of rebellers
  ConVar rebelColour = FindConVar("sm_hosties_rebel_color");
  if (rebelColour != null)
    SetConVarInt(rebelColour, 1);
    
  //Enable warden claiming
  ConVar wardenClaim = FindConVar("sm_warden_enabled");
  if (wardenClaim != null)
    SetConVarInt(wardenClaim, 1);
}

//Return time since new round started
int GetTimeSinceRoundStart()
{
  int curTime = GetTime();
  return (curTime - newRoundTimeElapsed);
}

//Set a special day
void setSpecialDay(int specialDayType = SPECIALDAY_NONE)
{
  specialDay = specialDayType;
  
  if (specialDay == SPECIALDAY_NONE)
    return;
  
  if (specialDay != SPECIALDAY_ROUNDMODIFIER) {
    //Disable LR on special days unless its a round modifier
    ConVar hostiesLR = FindConVar("sm_hosties_lr");
    if (hostiesLR != null)
      SetConVarInt(hostiesLR, 0);  
      
    //Disable colouring of rebellers
    ConVar rebelColour = FindConVar("sm_hosties_rebel_color");
    if (rebelColour != null)
      SetConVarInt(rebelColour, 0);
      
    //Disable warden claiming
    ConVar wardenClaim = FindConVar("sm_warden_enabled");
    if (wardenClaim != null)
      SetConVarInt(wardenClaim, 0);
  }
  
  ++numSpecialDays;
}

stock int GetAimOrigin(int client, float hOrigin[3], int type) 
{
    float vAngles[3], fOrigin[3];
    GetClientEyePosition(client, fOrigin);
    GetClientEyeAngles(client, vAngles);

    Handle trace;
    if (type == 1)
      trace = TR_TraceRayFilterEx(fOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
    else if (type == 2)
      trace = TR_TraceRayFilterEx(fOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterOnlyPlayer, client);
    
    if (TR_DidHit(trace)) {
      TR_GetEndPosition(hOrigin, trace);
      CloseHandle(trace);
      return 1;
    }

    CloseHandle(trace);
    return 0;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, int data) 
{
  return (entity > MaxClients || !entity);
}

public bool TraceEntityFilterOnlyPlayer(int entity, int contentsMask, int data) 
{
  return data != entity;
}

public Action PlaceLaserAction(int client, int args) {
  //Ensure user is warden
  bool isWarden = view_as<bool>(warden_iswarden(client));

  if (!isWarden) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
    return Plugin_Handled;
  }
  
  TraceEye(client, LastLaser[client]);
  LaserEnabled[client] = true;
  return Plugin_Handled;
}

public Action RemoveLaserAction(int client, int args) {
  LastLaser[client][0] = 0.0;
  LastLaser[client][1] = 0.0;
  LastLaser[client][2] = 0.0;
  LaserEnabled[client] = false;
  return Plugin_Handled;
}

stock void LaserP(float start[3], float end[3], int colour[4]) {
  TE_SetupBeamPoints(start, end, g_BeamSprite, 0, 0, 0, 25.0, 2.0, 2.0, 10, 0.0, colour, 0);
  TE_SendToAll();
}

void TraceEye(int client, float pos[3]) {
  float vAngles[3], vOrigin[3];
  GetClientEyePosition(client, vOrigin);
  GetClientEyeAngles(client, vAngles);
  TR_TraceRayFilter(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
  
  if (TR_DidHit(null))
    TR_GetEndPosition(pos, null);
  
  return;
}

public Action FadeClient(Handle timer, Handle pack)
{
  ResetPack(pack);
  
  int targets[2];
  targets[0] = ReadPackCell(pack);
  
  int color[4];
  color[0] = ReadPackCell(pack);
  color[1] = ReadPackCell(pack);
  color[2] = ReadPackCell(pack);
  color[3] = ReadPackCell(pack);
  
  int duration = 255;
  int holdtime = 255;
  
  int flags = (0x0002 | 0x0008);
  
  Handle message = StartMessageEx(g_FadeUserMsgId, targets, 1);
  
  if (GetUserMessageType() == UM_Protobuf)
  {
    Protobuf pb = UserMessageToProtobuf(message);
    pb.SetInt("duration", duration);
    pb.SetInt("hold_time", holdtime);
    pb.SetInt("flags", flags);
    pb.SetColor("clr", color);
  }
  else
  {
    BfWrite bf = UserMessageToBfWrite(message);
    bf.WriteShort(duration);
    bf.WriteShort(holdtime);
    bf.WriteShort(flags);    
    bf.WriteByte(color[0]);
    bf.WriteByte(color[1]);
    bf.WriteByte(color[2]);
    bf.WriteByte(color[3]);
  }
  
  EndMessage();

  return Plugin_Handled;
}

public Action UnfadeClient(Handle timer, Handle pack)
{
  ResetPack(pack);
  
  int targets[2];
  targets[0] = ReadPackCell(pack);
  int color[4];
  color[0] = ReadPackCell(pack);
  color[1] = ReadPackCell(pack);
  color[2] = ReadPackCell(pack);
  color[3] = ReadPackCell(pack);
  
  int duration = 1536;
  int holdtime = 1536;
  
  int flags = (0x0001 | 0x0010);

  Handle message = StartMessageEx(g_FadeUserMsgId, targets, 1);
  
  if (GetUserMessageType() == UM_Protobuf)
  {
    Protobuf pb = UserMessageToProtobuf(message);
    pb.SetInt("duration", duration);
    pb.SetInt("hold_time", holdtime);
    pb.SetInt("flags", flags);
    pb.SetColor("clr", color);
  }
  else
  {
    BfWrite bf = UserMessageToBfWrite(message);
    bf.WriteShort(duration);
    bf.WriteShort(holdtime);
    bf.WriteShort(flags);    
    bf.WriteByte(color[0]);
    bf.WriteByte(color[1]);
    bf.WriteByte(color[2]);
    bf.WriteByte(color[3]);
  }
  
  EndMessage();

  return Plugin_Handled;
}

public Action BlockPickup(int client, int weapon)
{
  if (specialDay) {
    if (specialDay == SPECIALDAY_VIRUSDAY) {
      char weaponClass[64];
      GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
      
      if (isInfected[client]) {
        if (StrEqual(weaponClass, "weapon_knife"))
          return Plugin_Continue;
        
        return Plugin_Handled;
      }
    }
    else if (specialDay == SPECIALDAY_HUNGERGAMES && !isPastHideTime) {
      char weaponClass[64];
      GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
      
      if (StrEqual(weaponClass, "weapon_knife"))
          return Plugin_Continue;

      return Plugin_Handled;
    }
  }
  
  return Plugin_Continue;
}

//Turn off Team DM
void turnOffTeamDM()
{
  SetConVarBool(FindConVar("mp_friendlyfire"), false);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), false);

  isInHighlightTeamDM = false;

  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Turned Off");
}

//Turn ON Team DM
void turnOnTeamDM()
{
  SetConVarBool(FindConVar("mp_friendlyfire"), true);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);

  isInHighlightTeamDM = true;

  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Team Deathmatch - Turned On");
}

//Get number of teams left alive in team DM (T Only)
int getTeamDMNumTeamsAlive_TOnly()
{
  //Check if at least two teams exist
  ArrayList teamsArray = CreateArray(MaxClients);

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T) {
        if (isHighlighted[i]) {
          int index = FindValueInArray(teamsArray, highlightedColour[i]);
          
          if (index == -1)
            PushArrayCell(teamsArray, highlightedColour[i]);
          
        }
      }
    }
  }
  
  return GetArraySize(teamsArray);
}

//Get number of teams left alive in team DM (T Only)
int getTeamDMNumTeamsAlive()
{
  //Check if at least two teams exist
  ArrayList teamsArray = CreateArray(MaxClients);

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        if (isHighlighted[i]) {
          int index = FindValueInArray(teamsArray, highlightedColour[i]);
          
          if (index == -1)
            PushArrayCell(teamsArray, highlightedColour[i]);
        }
      }
    }
  }
  
  return GetArraySize(teamsArray);
}

//Helper function
void removeClientFromArray(ArrayList array, int client)
{
  while (FindValueInArray(array, client) != -1)
  {
    RemoveFromArray(array, FindValueInArray(array, client));
  }
}

void Create_Model(int client)
{
  SafeDelete(infectedIcon[client]);
  infectedIcon[client] = CreateIcon();
  PlaceAndBindIcon(client, infectedIcon[client]);
}

int CreateIcon()
{
  int sprite = CreateEntityByName("env_sprite_oriented");
  
  if (sprite == -1)
    return -1;

  DispatchKeyValue(sprite, "classname", "env_sprite_oriented");
  DispatchKeyValue(sprite, "spawnflags", "1");
  DispatchKeyValue(sprite, "scale", "0.3");
  DispatchKeyValue(sprite, "rendermode", "1");
  DispatchKeyValue(sprite, "rendercolor", "255 255 255");
  DispatchKeyValue(sprite, "model", "materials/sprites/invex/infected.vmt");
  
  if (DispatchSpawn(sprite))
    return sprite;

  return -1;
}

void PlaceAndBindIcon(int client, int entity)
{
  float origin[3];

  if (IsValidEntity(entity)) {
    GetClientAbsOrigin(client, origin);
    origin[2] += 90.0;
    TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);

    SetVariantString("!activator");
    AcceptEntityInput(entity, "SetParent", client);
  }
}

void SafeDelete(int entity)
{
  if (IsValidEntity(entity))
    AcceptEntityInput(entity, "Kill");
}  

//Strip weapons
void StripWeapons(int client) {
  for (int i = 0; i < 44; i++) { 
    int index = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
    
    if(index && IsValidEdict(index))
      RemoveWeaponDrop(client, index);
  }
}

void RemoveWeaponDrop(int client, int entity) 
{
  if (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") != client) {
    LogAction(client, -1, "Weapon had incorrect owner. Entity was: %d. This may be an error.", entity);
    return;
  }
  
  if (IsClientInGame(client) && IsPlayerAlive(client) && IsValidEntity(entity)) {
    CS_DropWeapon(client, entity, true, true); 
    AcceptEntityInput(entity, "Kill");
  }
}

void VirusDay_InfectClient(int client, bool printMessage)
{
  isInfected[client] = true;
  
  //Set up tint
  Handle fadePack;
  CreateDataTimer(0.0, FadeClient, fadePack);
  WritePackCell(fadePack, client);
  WritePackCell(fadePack, redColour[0]);
  WritePackCell(fadePack, redColour[1]);
  WritePackCell(fadePack, redColour[2]);
  WritePackCell(fadePack, 15);
  
  //Highlight infected red
  SetEntityRenderColor(client, redColour[0], redColour[1], redColour[2], 255);
  
  //Play sound
  char infectSounds[3][] = {INFECT_SOUND_1, INFECT_SOUND_2, INFECT_SOUND_3};
  int randNum = GetRandomInt(0, sizeof(infectSounds) - 1);

  //Play explosion sounds
  EmitSoundToAllAny(infectSounds[randNum], client, SNDCHAN_USER_BASE, SNDLEVEL_RAIDSIREN); 
  
  //Strip all weapons
  StripWeapons(client);
  
  //Give them knife
  GivePlayerItem(client, "weapon_knife");
  
  //Overlay infected on them
  Create_Model(client);
  
  //Set blood overlay
  ShowOverlayToClient(client, "overlays/invex/infectedblood.vmt");
  
  //Set clan tag
  CS_SetClientClanTag(client, "[INFECTED]");
  
  //Set health
  SetEntProp(client, Prop_Data, "m_iHealth", GetConVarInt(cvar_virusday_infectedhealth));
  
  //Give speed boost
  SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", GetConVarFloat(cvar_virusday_infectedspeed));
  
  //Set gravity
  SetEntityGravity(client, GetConVarFloat(cvar_virusday_infectedgravity));
  
  //Burn if past cure time
  if (isPastCureFoundTime) {
    ServerCommand("sm_burn #%d 10000", GetClientUserId(client));
  }
  
  if (printMessage)
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Virus Day New Infected", client);

  VirusDay_CheckInfectedOver();
    
  return;
}

void VirusDay_CheckInfectedOver()
{
  //Pick two people to infect
  int nonInfected = 0;
  int infected = 0;
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (isInfected[i])
        ++infected;
      else
        ++nonInfected;
    }
  }
  
  if (infected == 0) {
    //Round over, everybody is infected
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Virus Day Non Infected Win Died Off");
    
    //Fire CT Win
    CS_TerminateRound(GetConVarFloat(FindConVar("mp_round_restart_delay")), CSRoundEnd_CTWin, false);
  }
  if (nonInfected == 0) {
    //Round over, everybody is infected
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Virus Day All Infected");
    
    //Fire Prisoners Win
    CS_TerminateRound(GetConVarFloat(FindConVar("mp_round_restart_delay")), CSRoundEnd_TerroristWin, false);
  }
}

void ShowOverlayToClient(int client, const char[] overlaypath)
{
  ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}

public Action RemoveOverlay(Handle timer, int client)
{
  //Remove overlay
  ShowOverlayToClient(client, "");
}

void RemoveRadar(int client) 
{
  if(client == 0)
    return;

  SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDE_RADAR_CSGO);
}

//From: https://forums.alliedmods.net/showthread.php?t=111684
void DealDamage(int victim, int damage, int attacker=0, dmg_type=DMG_GENERIC, char weapon[] = "")
{
  if (victim>0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage>0) {
    char dmg_str[16];
    IntToString(damage, dmg_str, sizeof(dmg_str));
    char dmg_type_str[32];
    IntToString(dmg_type, dmg_type_str, sizeof(dmg_type_str));
    
    int  pointHurt = CreateEntityByName("point_hurt");
    
    if(pointHurt) {
      DispatchKeyValue(victim, "targetname", "war3_hurtme");
      DispatchKeyValue(pointHurt, "DamageTarget", "war3_hurtme");
      DispatchKeyValue(pointHurt, "Damage", dmg_str);
      DispatchKeyValue(pointHurt, "DamageType", dmg_type_str);
      if (!StrEqual(weapon,"")) {
        DispatchKeyValue(pointHurt,"classname",weapon);
      }
      DispatchSpawn(pointHurt);
      AcceptEntityInput(pointHurt, "Hurt", (attacker>0)?attacker:-1);
      DispatchKeyValue(pointHurt, "classname", "point_hurt");
      DispatchKeyValue(victim, "targetname", "war3_donthurtme");
      RemoveEdict(pointHurt);
    }
  }
}

//Disble the medic (or anything that heals, negative valued trigger_hurt's) until the end of the round
public void Disable_Medics()
{
  int entity = -1;
  while ((entity = FindEntityByClassname(entity, "trigger_hurt")) != INVALID_ENT_REFERENCE) {
    if (GetEntPropFloat(entity, Prop_Data, "m_flDamage") < 0) {
      AcceptEntityInput(entity, "Disable");
    }
  }
}

//Teleports players to beam that spawns on wardens location
//Players are also frozen before being teleported
//Uses: teleportHandle as handle (should be set to null in teleportFunc)
//teleportFunc is: Teleport_Start_All, Teleport_Start_T
//teleportType is: 0 for all players, 1 for T's
void TeleportPlayersToWarden(int warden, float tptime, char[] specialDayName, Timer teleportFunc, int teleportType)
{
  float warden_origin[3];
  float warden_angles[3];
  GetClientAbsOrigin(warden, warden_origin);
  GetClientAbsAngles(warden, warden_angles);
 
  //Create timer with pack
  Handle pack;
  teleportHandle = CreateDataTimer(tptime, teleportFunc, pack);
  
  if (teleportType == TELEPORTTYPE_ALL)
    ServerCommand("sm_freeze @all %d", RoundToFloor(tptime));
  else if (teleportType == TELEPORTTYPE_T)
    ServerCommand("sm_freeze @t %d", RoundToFloor(tptime));
    
  //Day name
  WritePackString(pack, specialDayName);
  
  //Origin
  WritePackFloat(pack, warden_origin[0]);
  WritePackFloat(pack, warden_origin[1]);
  WritePackFloat(pack, warden_origin[2]);
  
  //Angles
  WritePackFloat(pack, warden_angles[0]);
  WritePackFloat(pack, warden_angles[1]);
  WritePackFloat(pack, warden_angles[2]);
  
  //Draw beam (rally point)
  int excessDurationCount = RoundToFloor(tptime / 10.0);
  --excessDurationCount;
  
  if (excessDurationCount != 0) {
    //Start timer to recreate beacon
    Handle beampack;
    CreateDataTimer(10.0, ExcessBeamSpawner, beampack);
    WritePackCell(beampack, excessDurationCount);
    
    //Origin
    WritePackFloat(beampack, warden_origin[0]);
    WritePackFloat(beampack, warden_origin[1]);
    WritePackFloat(beampack, warden_origin[2]);
    
    //RGB Colour
    WritePackCell(beampack, currentColour[0]);
    WritePackCell(beampack, currentColour[1]);
    WritePackCell(beampack, currentColour[2]);
    WritePackCell(beampack, currentColour[3]);
  }

  //Draw Beam
  TE_SetupBeamRingPoint(warden_origin, 75.0, 75.5, g_BeamSprite, g_HaloSprite, 0, 0, 10.0, 10.0, 0.0, currentColour, 0, 0);
  TE_SendToAll();
}

//Sets a new clan tag while preserving the previous clan tag
void setAndPreserveClanTag(int client, char[] newClanTag)
{
  //Preserve current clan tag
  CS_GetClientClanTag(client, clantagStorage[client], sizeof(clantagStorage[]));
  restoreClanTags = true;
  
  //Set clan tag
  CS_SetClientClanTag(client, newClanTag);
}


/*********************************
 * Natives
 *********************************/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  CreateNative("WardenTools_IsSpecialDay", Native_IsSpecialDay);
  
  RegPluginLibrary("wardentools");
  
  return APLRes_Success;
}

public int Native_IsSpecialDay(Handle plugin, int numParams)
{
  return (specialDay != SPECIALDAY_NONE);
}