package states;

import systems.Replay;
import flixel.util.FlxStringUtil;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import gameplay.Boyfriend;
import gameplay.Character;
import gameplay.GameplayUI;
import gameplay.Note;
import gameplay.Song;
import gameplay.Stage;
import hscript.HScript;
import openfl.media.Sound;
import substates.ScriptedSubState;
import sys.FileSystem;
import systems.Conductor;
import systems.Highscore;
import systems.MusicBeat;
import systems.UIControls;

using StringTools;

typedef UnspawnNote = {
	var strumTime:Float; // 0 = strum tie m
	var noteData:Int; // 1 = ntpeo data
	var susLength:Float; // 2 = sussy amongle sus length! (sustain length)
	var mustPress:Bool; // 3 = must press
	var altAnim:Bool; // 4 = alt anim
}

class PlayState extends MusicBeatState {
	public static var logs:String = "";
	public static var current:PlayState;

	// Song
	public static var isStoryMode:Bool = false;
	public static var SONG:Song = SongLoader.getJSON("m.i.l.f", "hard");
	public static var actualSongName:String = "";

	public static var currentDifficulty:String = "hard";
	public static var availableDifficulties:Array<String> = ["easy", "normal", "hard"];

	public var unspawnNotes:Array<UnspawnNote> = [];

	// Characters
	public var dad:Character;
	public var gf:Character;
	public var bf:Boyfriend;

	// Camera
	public var camZooming:Bool = true;
	public var defaultCamZoom:Float = 1.0;

	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;
	public var camOther:FlxCamera;

	public var camFollow:FlxPoint;
	public var camFollowPos:FlxObject;

	public var cameraSpeed:Float = 1;

	// Music & Sounds
	public var freakyMenu:Sound = FNFAssets.returnAsset(SOUND, AssetPaths.music("freakyMenu"));
	public var loadedSong:Map<String, Sound> = [];
	public var vocals:FlxSound = new FlxSound();

	public var hasVocals:Bool = true;

	// Song Stats
	public var songScore:Int = 0;
	public var songMisses:Int = 0;

	public var songAccuracy:Float = 0;

	public var totalNotes:Int = 0;
	public var totalHit:Float = 0.0;

	public var combo:Int = 0;

	// Misc
	public var health:Float = 1.0;
	public var minHealth:Float = 0.0;
	public var maxHealth:Float = 2.0;

	public var healthGain:Float = 0.023;
	public var healthLoss:Float = 0.0475;

	public var stage:Stage;
	public var inCutscene:Bool = false;
	
	public var botPlay:Bool = Settings.get("Botplay");

	public var script:HScript;
	public var scripts:Array<HScript> = [];

	public var UI:GameplayUI;

	public var startedSong:Bool = false;
	public var endingSong:Bool = false;

	public var scrollSpeed:Float = 1.0;

	public var inReplay:Bool = false;

	public var replayData:ReplayData = {
		packUsed: AssetPaths.currentPack,

		justPressed: [],
		pressed: [],
		justReleased: [],

		notes: []
	};

	public function calculateAccuracy()
	{
		if(totalNotes != 0 && totalHit != 0)
			songAccuracy = totalHit / totalNotes;
		else
			songAccuracy = 0;
	}

	public var currentSkin:String = "default";

	public var ratingAssetPath:String = "ratings/default";
	public var comboAssetPath:String = "combo/default";

	public var countdownImageLocation = "countdown";
	public var countdownSoundLocation = "countdown/default";

	public var countdownGraphics:Map<String, FlxGraphic> = [];
	public var countdownSounds:Map<String, Sound> = [];

	public var ratingScale:Float = 0.7;
	public var comboScale:Float = 0.5;
	public var countdownScale:Float = 1.0;

	public var ratingAntialiasing:Bool = true;
	public var comboAntialiasing:Bool = true;

	public var usedPractice:Bool = false;
	public var practiceMode:Bool = false;

	public var cachedRatings:Map<String, FlxGraphic> = [];
	public var cachedCombo:Map<String, Map<String, FlxGraphic>> = [];

	public var logsOpen:Bool = false;
	
	override function create()
	{
		current = this;
		super.create();

		ChartEditor.stateClass = PlayState;

		// cache "breakfast" from music folder because pause menu!
		FNFAssets.returnAsset(SOUND, AssetPaths.music("breakfast"));

		persistentUpdate = true;
		persistentDraw = true;

		FlxG.sound.music.stop();
		FlxG.sound.list.add(vocals);

		if(SONG == null)
			SONG = SongLoader.getJSON("tutorial", "hard");

		if(SONG.keyCount == null)
			SONG.keyCount = 4;

		DiscordRPC.changePresence(
			'Playing ${SONG.song}',
			'Starting song...'
		);

		Conductor.changeBPM(SONG.bpm);
		Conductor.mapBPMChanges(SONG);

		Conductor.position = Conductor.crochet * -5.0;

		scrollSpeed = (Settings.get("Scroll Speed") > 0) ? Settings.get("Scroll Speed") : SONG.speed;

		loadedSong.set("inst", FNFAssets.returnAsset(SOUND, AssetPaths.songInst(SONG.song)));
		
		hasVocals = FileSystem.exists(AssetPaths.songVoices(SONG.song));
		if(hasVocals)
		{
			loadedSong.set("voices", FNFAssets.returnAsset(SOUND, AssetPaths.songVoices(SONG.song)));
			vocals.loadEmbedded(loadedSong.get("voices"), false);
		}

		setupCameras();

		callOnHScripts("create");

		stage = new Stage(SONG.stage != null ? SONG.stage : "stage");
		add(stage);

		callOnHScripts("createAfterStage");

		var gfVersion:String = "gf";

		if(SONG.player3 != null)
			gfVersion = SONG.player3;

		// me when deprecated variable that makes me angy on compile >:(
		//   -Raf

		// me when that breaks compatibility with some psych charts so we have it back and just make it not deprecated instead?
		//   -Leather

		if(SONG.gfVersion != null)
			gfVersion = SONG.gfVersion;

		if(SONG.gf != null)
			gfVersion = SONG.gf;

		gf = new Character(stage.gfPosition.x, stage.gfPosition.y, gfVersion);
		gf.scrollFactor.set(0.95, 0.95);

		if (gf.trail != null)
			add(gf.trail);

		add(gf);
		add(stage.inFrontOfGFSprites);

		dad = new Character(stage.dadPosition.x, stage.dadPosition.y, SONG.player2);
		dad.isPlayer = false;

		if (dad.trail != null)
			add(dad.trail);

		add(dad);

		// what if i told you the dad was the impostor!?!!?!
		if(dad.curCharacter == gf.curCharacter)
		{
			dad.goToPosition(stage.gfPosition.x, stage.gfPosition.y);

			if (gf.trail != null)
				remove(gf.trail, true);

			remove(gf, true);
			gf.kill();
			gf.destroy();
			gf = null;
		}

		bf = new Boyfriend(stage.bfPosition.x, stage.bfPosition.y, SONG.player1);
		bf.flipX = !bf.flipX;

		if (bf.trail != null)
			add(bf.trail);

		add(bf);
		add(stage.foregroundSprites);

		if(stage.script != null)
		{
			stage.script.set("dad", dad);
			stage.script.set("gf", gf);
			stage.script.set("bf", bf);
		}

		callOnHScripts("createAfterChars");

		// load the song script
		var path:String = 'songs/${actualSongName.toLowerCase()}/script';
		script = new HScript(path);
		script.set("add", this.add);
		script.set("remove", this.remove);
		scripts.push(script);
		script.start();

		// load global scripts
		if(FileSystem.exists(AssetPaths.asset('global_scripts')))
		{
			for(item in FileSystem.readDirectory(AssetPaths.asset('global_scripts')))
			{
				if(item.contains("."))
				{
					var real = item;
					for(ext in HScript.hscriptExts)
						real = real.replace(ext, "");

					var path:String = 'global_scripts/$real';
					var script = new HScript(path);
					script.set("add", this.add);
					script.set("remove", this.remove);
					scripts.push(script);
					script.start();
				}
			}
		}

		// precache the countdown bullshit
		countdownGraphics = [
			"preready"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(countdownImageLocation+"/"+"preready")),
			"ready"      => FNFAssets.returnAsset(IMAGE, AssetPaths.image(countdownImageLocation+"/"+"ready")),
			"set"        => FNFAssets.returnAsset(IMAGE, AssetPaths.image(countdownImageLocation+"/"+"set")),
			"go"         => FNFAssets.returnAsset(IMAGE, AssetPaths.image(countdownImageLocation+"/"+"go")),
		];

		countdownSounds = [
			"preready"   => FNFAssets.returnAsset(SOUND, AssetPaths.sound(countdownSoundLocation+"/"+"intro3")),
			"ready"      => FNFAssets.returnAsset(SOUND, AssetPaths.sound(countdownSoundLocation+"/"+"intro2")),
			"set"        => FNFAssets.returnAsset(SOUND, AssetPaths.sound(countdownSoundLocation+"/"+"intro1")),
			"go"         => FNFAssets.returnAsset(SOUND, AssetPaths.sound(countdownSoundLocation+"/"+"introGo")),
		];

		countdownPreReady.cameras = [camHUD];
		countdownPreReady.alpha = 0;
		add(countdownPreReady);

		countdownReady.cameras = [camHUD];
		countdownReady.alpha = 0;
		add(countdownReady);

		countdownSet.cameras = [camHUD];
		countdownSet.alpha = 0;
		add(countdownSet);

		countdownGo.cameras = [camHUD];
		countdownGo.alpha = 0;
		add(countdownGo);

		if(!inCutscene)
			startCountdown();

		FlxG.camera.zoom = defaultCamZoom;

		UI = new GameplayUI();
		
		for(section in SONG.notes)
		{
			if(section != null)
			{
				for(note in section.sectionNotes)
				{
					var strumTime:Float = note[0] + Settings.get("Note Offset");
					var gottaHitNote:Bool = section.mustHitSection;
					if (note[1] > (SONG.keyCount - 1))
						gottaHitNote = !section.mustHitSection;

					var susLength:Float = note[2] / Conductor.stepCrochet;

					var altAnim:Bool = section.altAnim;
					if(note[3])
						altAnim = note[3];

					unspawnNotes.push({
						strumTime: strumTime, // 0 = strum tie m
						noteData: Std.int(note[1] % SONG.keyCount), // 1 = ntpeo data
						susLength: susLength, // 2 = sussy amongle sus length! (sustain length)
						mustPress: gottaHitNote, // 3 = must press
						altAnim: altAnim // 4 = alt anim
					});
				}
			}
		}

		unspawnNotes.sort(sortByShit);

		UI.cameras = [camHUD];
		add(UI);

		cachedRatings = getRatingCache(ratingAssetPath);
		cachedCombo = getComboCache(comboAssetPath);

		camFollow = new FlxPoint();
		camFollowPos = new FlxObject(0, 0, 1, 1);
		add(camFollowPos);
		
		FlxG.camera.follow(camFollowPos, LOCKON, 1);

		if(gf != null)
		{
			camFollow.set(gf.getMidpoint().x, gf.getMidpoint().y);
			camFollowPos.setPosition(camFollow.x, camFollow.y);
		}

		focusCamera(SONG.notes[0].mustHitSection ? "bf" : "dad");

		callOnHScripts("createPost");
	}

	function getRatingCache(ratingPath:String = "ratings/default")
	{
		return [
			"marvelous"  => FNFAssets.returnAsset(IMAGE, AssetPaths.image(ratingPath+"/"+"marvelous")),
			"sick"       => FNFAssets.returnAsset(IMAGE, AssetPaths.image(ratingPath+"/"+"sick")),
			"good"       => FNFAssets.returnAsset(IMAGE, AssetPaths.image(ratingPath+"/"+"good")),
			"bad"        => FNFAssets.returnAsset(IMAGE, AssetPaths.image(ratingPath+"/"+"bad")),
			"shit"       => FNFAssets.returnAsset(IMAGE, AssetPaths.image(ratingPath+"/"+"shit")),
		];
	}

	function getComboCache(comboPath:String = "combo/default")
	{
		return [
			"marvelous"  => [
				"combo"  => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/"+"combo")),
				"num0"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/"+"num0")),
				"num1"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/"+"num1")),
				"num2"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/"+"num2")),
				"num3"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/"+"num3")),
				"num4"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/"+"num4")),
				"num5"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/"+"num5")),
				"num6"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/"+"num6")),
				"num7"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/"+"num7")),
				"num8"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/"+"num8")),
				"num9"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/"+"num9")),
			],
			"default"    => [
				"combo"  => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/"+"combo")),
				"num0"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/"+"num0")),
				"num1"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/"+"num1")),
				"num2"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/"+"num2")),
				"num3"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/"+"num3")),
				"num4"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/"+"num4")),
				"num5"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/"+"num5")),
				"num6"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/"+"num6")),
				"num7"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/"+"num7")),
				"num8"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/"+"num8")),
				"num9"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/"+"num9")),
			],
		];
	}

	public function getMenuToSwitchTo():Dynamic
	{
		if(isStoryMode)
			return new states.ScriptedState('StoryMenu'); // i changed it!!!
		else
			return new states.ScriptedState('FreeplayMenu');

		return null;
	}

	public var countdownPreReady:FlxSprite = new FlxSprite();
	public var countdownReady:FlxSprite = new FlxSprite();
	public var countdownSet:FlxSprite = new FlxSprite();
	public var countdownGo:FlxSprite = new FlxSprite();

	public var countdownTimer:FlxTimer;

	public var countdownTick:Int = 0;
	public function startCountdown()
	{		
		countdownTimer = new FlxTimer().start(Conductor.crochet / 1000.0, function(tmr:FlxTimer) {
			if(dad != null)
				dad.dance();

			if(gf != null)
				gf.dance();

			if(bf != null)
				bf.dance();

			switch(countdownTick)
			{
				case 0:
					callOnHScripts("countdownTick", [countdownTick]);
					FlxG.sound.play(countdownSounds["preready"]);
					countdownPreReady.loadGraphic(countdownGraphics["preready"]);
					countdownPreReady.scale.set(countdownScale, countdownScale);
					countdownPreReady.updateHitbox();
					countdownPreReady.screenCenter();
					countdownPreReady.alpha = 1;
					FlxTween.tween(countdownPreReady, { alpha: 0 }, Conductor.crochet / 1000.0, { ease: FlxEase.cubeInOut });
				case 1:
					callOnHScripts("countdownTick", [countdownTick]);
					FlxG.sound.play(countdownSounds["ready"]);
					countdownReady.loadGraphic(countdownGraphics["ready"]);
					countdownReady.scale.set(countdownScale, countdownScale);
					countdownReady.updateHitbox();
					countdownReady.screenCenter();
					countdownReady.alpha = 1;
					FlxTween.tween(countdownReady, { alpha: 0 }, Conductor.crochet / 1000.0, { ease: FlxEase.cubeInOut });
				case 2:
					callOnHScripts("countdownTick", [countdownTick]);
					FlxG.sound.play(countdownSounds["set"]);
					countdownSet.loadGraphic(countdownGraphics["set"]);
					countdownSet.scale.set(countdownScale, countdownScale);
					countdownSet.updateHitbox();
					countdownSet.screenCenter();
					countdownSet.alpha = 1;
					FlxTween.tween(countdownSet, { alpha: 0 }, Conductor.crochet / 1000.0, { ease: FlxEase.cubeInOut });
				case 3:
					callOnHScripts("countdownTick", [countdownTick]);
					FlxG.sound.play(countdownSounds["go"]);
					countdownGo.loadGraphic(countdownGraphics["go"]);
					countdownGo.scale.set(countdownScale, countdownScale);
					countdownGo.updateHitbox();
					countdownGo.screenCenter();
					countdownGo.alpha = 1;
					FlxTween.tween(countdownGo, { alpha: 0 }, Conductor.crochet / 1000.0, { ease: FlxEase.cubeInOut });
				case 4:
					callOnHScripts("countdownTick", [countdownTick]);
			}

			countdownTick++;
		}, 5);
	}

	function kindaEndSong()
	{
		FlxG.sound.music.stop();
		vocals.stop();
		FlxG.sound.music.time = 0;
		FlxG.sound.playMusic(freakyMenu);
		callOnHScripts("endSong", [actualSongName]);
		
		Main.switchState(getMenuToSwitchTo());
	}

	function endSong()
	{
		if(!inCutscene)
		{
			endingSong = true;

			FlxG.sound.music.stop();
			vocals.stop();

			FlxG.sound.music.time = 0;
			FlxG.sound.playMusic(freakyMenu);
			
			if(!usedPractice && songScore > Highscore.getScore(actualSongName+"-"+currentDifficulty))
				Highscore.setScore(actualSongName+"-"+currentDifficulty, songScore);
			
			var ret:Dynamic = callOnHScripts("endSong", [actualSongName]);
			
			if(ret != HScript.function_stop)
			{
				if(isStoryMode)
				{
					trace("die, now.");
				}
				else
					Main.switchState(getMenuToSwitchTo());
			}
		}
	}

	var discordRPCTimer:Float = 0.0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(!inCutscene)
		{
			var lerpVal:Float = FlxMath.bound(Main.deltaTime * 2.4 * cameraSpeed, 0, 1);
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		}

		callOnHScripts("update", [elapsed]);

		if(FlxG.keys.justPressed.SEVEN)
		{
			ChartEditor.stateClass = PlayState;
			Main.switchState(new ChartEditor());
		}

		if(FlxG.keys.justPressed.F6 && !logsOpen)
		{
			logsOpen = true;
			openSubState(new ScriptedSubState('Logs'));
		}

		if(UIControls.justPressed("BACK") || (Conductor.position >= FlxG.sound.music.length))
		{
			persistentUpdate = false;
			persistentDraw = true;
			
			endingSong = true;

			var func = UIControls.justPressed("BACK") ? kindaEndSong : endSong;
			func();
		}

		if(!inCutscene && !UIControls.justPressed("BACK") && UIControls.justPressed("PAUSE"))
		{
			logsOpen = false;
			
			persistentUpdate = false;
			persistentDraw = true;

			openSubState(new substates.PauseMenu());
		}

		if(!inCutscene)
		{
			Conductor.position += elapsed * 1000.0;
			if(Conductor.position >= 0.0 && !startedSong)
				startSong();
		}

		if(startedSong && !endingSong)
		{
			discordRPCTimer += elapsed;
			if(discordRPCTimer > 1.0)
			{
				discordRPCTimer = 0.0;
				DiscordRPC.changePresence(
					'Playing ${SONG.song} on ${CoolUtil.firstLetterUppercase(currentDifficulty)}',
					'Time remaining: ${FlxStringUtil.formatTime((FlxG.sound.music.length-FlxG.sound.music.time)/1000.0)} / ${FlxStringUtil.formatTime(FlxG.sound.music.length/1000.0)}'
				);
			}
		}

		if(health <= minHealth)
		{
			health = minHealth;

			if(!practiceMode)
			{
				persistentUpdate = false;
				persistentDraw = false;

				//openSubState(new GameOver(bf.x, bf.y, camFollowPos.x, camFollowPos.y, bf.deathCharacter));
				openSubState(new ScriptedSubState('GameOver', [bf.x, bf.y, camFollowPos.x, camFollowPos.y, bf.deathCharacter]));
			}
		}

		spawnNotes();

		if(camZooming)
		{
			FlxG.camera.zoom = FlxMath.lerp(FlxG.camera.zoom, defaultCamZoom, Main.deltaTime * 9);
			camHUD.zoom = FlxMath.lerp(camHUD.zoom, 1, Main.deltaTime * 9);
		}

		callOnHScripts("updatePost", [elapsed]);
	}

	override function resetState()
	{
		persistentUpdate = false;
		persistentDraw = true;
		
		Main.resetState();
	}

	function sortByShit(Obj1:UnspawnNote, Obj2:UnspawnNote):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime);

	function spawnNotes()
	{
		if(unspawnNotes[0] != null)
		{
			while (unspawnNotes.length > 0 && (unspawnNotes[0].strumTime - Conductor.position) < 1500 / scrollSpeed)
			{
				var arrowSkin:String = currentSkin != "default" ? currentSkin : Settings.get("Arrow Skin").toLowerCase();

				var dunceNote:Note = new Note(-9999, -9999, unspawnNotes[0].noteData, false);
				dunceNote.strumTime = unspawnNotes[0].strumTime;
				dunceNote.mustPress = unspawnNotes[0].mustPress;
				dunceNote.altAnim = unspawnNotes[0].altAnim;
				dunceNote.parent = unspawnNotes[0].mustPress ? UI.playerStrums : UI.opponentStrums;
				dunceNote.loadSkin(arrowSkin);

				var cum:Int = Math.floor(unspawnNotes[0].susLength);
				for(i in 0...cum)
				{
					var susNote:Note = new Note(-9999, -9999, unspawnNotes[0].noteData, true);
					susNote.strumTime = unspawnNotes[0].strumTime + (Conductor.stepCrochet * i) + Conductor.stepCrochet;
					susNote.mustPress = unspawnNotes[0].mustPress;
					susNote.altAnim = unspawnNotes[0].altAnim;
					susNote.parent = unspawnNotes[0].mustPress ? UI.playerStrums : UI.opponentStrums;
					susNote.loadSkin(arrowSkin);
					if(i >= cum-1)
					{
						susNote.isEndPiece = true;
						susNote.playAnim("tail");
					}
					susNote.sustainParent = dunceNote;
					susNote.parent.notes.add(susNote);
				}

				dunceNote.parent.notes.add(dunceNote);

				unspawnNotes.shift();
			}
		}
	}

	function startSong()
	{
		startedSong = true;

		FlxG.sound.playMusic(loadedSong.get("inst"), 1, false);
		if(hasVocals)
			vocals.play();

		Conductor.position = 0.0;
		callOnHScripts("startSong", [SONG.song]);
	}

	public function focusCamera(onWho:String = "dad")
	{
		switch(onWho.toLowerCase())
		{
			case "dad":
				if(dad == null) return trace("dad is null!!");
				camFollow.set(dad.getCamPos().x, dad.getCamPos().y);
			case "bf":
				if(bf == null) return trace("bf is null!!");
				camFollow.set(bf.getCamPos().x, bf.getCamPos().y);
		}
	}

	override function beatHit()
	{
		super.beatHit();

		// Stop the function from running if the song is ending
		if(endingSong) return;

		var curSection:Int = Std.int(FlxMath.bound(Conductor.currentStep / 16, 0, SONG.notes.length-1));
		focusCamera(SONG.notes[curSection].mustHitSection ? "bf" : "dad");

		if (SONG.notes[curSection].changeBPM)
			Conductor.changeBPM(SONG.notes[curSection].bpm);

		if(dad != null && dad.animation.curAnim != null && !dad.animation.curAnim.name.startsWith("sing"))
			dad.dance();

		if(gf != null && gf.animation.curAnim != null && !gf.animation.curAnim.name.startsWith("sing"))
			gf.dance();

		if(bf != null && bf.animation.curAnim != null && !bf.animation.curAnim.name.startsWith("sing"))
			bf.dance();

		callOnHScripts("beatHit", [Conductor.currentBeat]);

		if(camZooming && Conductor.currentBeat % 4 == 0)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.04;
		}

		callOnHScripts("beatHitPost", [Conductor.currentBeat]);
	}

	override function stepHit()
	{
		super.stepHit();

		callOnHScripts("stepHit", [Conductor.currentStep]);

		// Resync song if it gets out of sync with song position
		resyncSong();

		callOnHScripts("stepHitPost", [Conductor.currentStep]);
	}

	public function resyncSong()
	{
		if(hasVocals)
		{
			if(!(Conductor.isAudioSynced(FlxG.sound.music) && Conductor.isAudioSynced(vocals)))
			{
				FlxG.sound.music.pause();
				if(vocals.time < vocals.length)
					vocals.pause();

				FlxG.sound.music.time = Conductor.position;
				if(vocals.time < vocals.length)
					vocals.time = Conductor.position;

				FlxG.sound.music.play();
				if(vocals.time < vocals.length)
					vocals.play();
			}
		}
		else
		{
			if(!Conductor.isAudioSynced(FlxG.sound.music))
			{
				FlxG.sound.music.pause();
				FlxG.sound.music.time = Conductor.position;
				FlxG.sound.music.play();
			}
		}
	}

	function setupCameras()
	{
		FlxG.cameras.remove(camNotif, false);

		camGame = FlxG.camera;
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor = 0x0;
		camOther.bgColor = 0x0;

		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		FlxG.cameras.add(camNotif, false);
	}

	public function callOnHScripts(func:String, ?args:Null<Array<Dynamic>>):Dynamic
	{
		var returnVal:Dynamic = HScript.function_continue;
		for(script in scripts)
		{
			var ret:Dynamic = script.call(func, args);
			if(ret == HScript.function_stop)
				break;

			var bool:Bool = ret == HScript.function_continue;
			if(!bool)
				returnVal = cast ret;
		}
		
		return returnVal;
	}

	override function destroy()
	{
		super.destroy();
		current = null;
	}
}
