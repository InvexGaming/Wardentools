/*
* Blind toggle
* Prefix: blind_
*/

#if defined _wardentools_blind_included
  #endinput
#endif
#define _wardentools_blind_included

#include <wardentools>
#include <cstrike>

static UserMsg g_FadeUserMsgId; //For Blind
static bool isBlind[MAXPLAYERS+1] = false;
static bool shouldBlind = false;

//OnPluginStart
public void Blind_OnPluginStart()
{
  g_FadeUserMsgId = GetUserMessageId("Fade");
  
  HookEvent("player_death", Blind_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("round_prestart", Blind_Reset, EventHookMode_Post);
}

//Player death hook
public Action Blind_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  //Unblind all clients on death who are blind
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (isBlind[client]) {
    Handle fadePack;
    CreateDataTimer(0.0, Blind_UnfadeClient, fadePack);
    WritePackCell(fadePack, client);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 0);
    WritePackCell(fadePack, 0);
  }
}

//OnClientPutInServer
public void Blind_OnClientPutInServer(int client)
{
  isBlind[client] = false;
}

public void Blind_ToggleTeamBlind(int team)
{
  shouldBlind = !shouldBlind; //toggle command

  for (int i = 1; i <= MaxClients ; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == team) {
         if (shouldBlind) {
           isBlind[i] = true;
           
           Handle fadePack;
           CreateDataTimer(0.0, Blind_FadeClient, fadePack);
           WritePackCell(fadePack, i);
           WritePackCell(fadePack, 0);
           WritePackCell(fadePack, 0);
           WritePackCell(fadePack, 0);
           WritePackCell(fadePack, 255);
         }
         else {
           isBlind[i] = false;
           
           Handle fadePack;
           CreateDataTimer(0.0, Blind_UnfadeClient, fadePack);
           WritePackCell(fadePack, i);
           WritePackCell(fadePack, 0);
           WritePackCell(fadePack, 0);
           WritePackCell(fadePack, 0);
           WritePackCell(fadePack, 0);
         }
      }
    }
  }
  
  char teamName[32];
  if (team == CS_TEAM_T)
    Format(teamName, sizeof(teamName), "prisoners");
  else if (team == CS_TEAM_CT)
    Format(teamName, sizeof(teamName), "guards");
  else
    Format(teamName, sizeof(teamName), "unknown-teams");
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Gamemode - Blind", teamName);
}

//Round pre start
public void Blind_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
    
    //Unblind all
    if (isBlind[i]) {
      Handle fadePack;
      CreateDataTimer(0.0, Blind_UnfadeClient, fadePack);
      WritePackCell(fadePack, i);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 0);
      
      isBlind[i] = false;
    }
  }
  
  shouldBlind = false;
}


public Action Blind_FadeClient(Handle timer, Handle pack)
{
  ResetPack(pack);
  
  int targets[2];
  targets[0] = ReadPackCell(pack);
  
  if (!IsClientConnected(targets[0]) || IsFakeClient(targets[0]))
    return Plugin_Handled;
  
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

public Action Blind_UnfadeClient(Handle timer, Handle pack)
{
  ResetPack(pack);
  
  int targets[2];
  targets[0] = ReadPackCell(pack);
  
  if (!IsClientConnected(targets[0]) || IsFakeClient(targets[0]))
    return Plugin_Handled;
  
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

//Getters/Setters
public void Blind_SetBlind(int client, bool value)
{
  isBlind[client] = value;
}