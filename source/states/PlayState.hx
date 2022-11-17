package states;

import compat.psych.PsychEventHandler;
import gameplay.Events;
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
import flixel.util.FlxStringUtil;
import flixel.util.FlxTimer;
import gameplay.Boyfriend;
import gameplay.Character;
import gameplay.GameplayUI;
import gameplay.Note;
import gameplay.Song;
import gameplay.Stage;
import hscript.HScript;
import openfl.media.Sound;
import openfl.utils.Dictionary;
import substates.ScriptedSubState;
import sys.FileSystem;
import sys.io.File;
import systems.Conductor;
import systems.Highscore;
import systems.MusicBeat;
import systems.ScriptedSprite;
import systems.UIControls;

// Widescreen imports
import flixel.system.scaleModes.RatioScaleMode;
import flixel.system.scaleModes.StageSizeScaleMode;
import flixel.system.scaleModes.BaseScaleMode;

using StringTools;

typedef UnspawnNote = {
	var strumTime:Float; // 0 = strum tie m
	var noteData:Int; // 1 = ntpeo data
	var susLength:Float; // 2 = sussy amongle sus length! (sustain length)
	var mustPress:Bool; // 3 = must press
	var altAnim:Bool; // 4 = alt anim
}

class PlayState extends MusicBeatState {
	public static var current:PlayState;

	// Song
	public static var isStoryMode:Bool = false;
	public static var SONG:Song = SongLoader.getJSON("tutorial");
	public static var actualSongName:String = "";

	public static var songMultiplier:Float = 1.0;

	public static var storyScore:Int = 0;

	public static var actualWeekName:String = "";
	public static var storyPlaylist:Array<String> = [];

	public static var currentDifficulty:String = "hard";
	public static var availableDifficulties:Array<String> = ["easy", "normal", "hard"];

	public var unspawnNotes:Array<UnspawnNote> = [];

	// Characters
	public var dad:Character;
	public var gf:Character;
	public var bf:Boyfriend;

	public var dads:Array<Character> = [];
	public var bfs:Array<Character> = [];

	// Camera
	/**
		Controls if the camera is allowed to lerp back to it's default zoom.
	**/
	public var camZooming:Bool = true;
	/**
		Controls if the camera is allowed to zoom in every few beats.
	**/
	public var camBumping:Bool = true;

	public var defaultCamZoom:Float = 1.0;

	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;
	public var camOther:FlxCamera;

	public var camFollow:FlxPoint;
	public var camFollowPos:FlxObject;

	public var cameraSpeed:Float = 1.5;

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

	public var customHealth:Bool = false;

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

	public function calculateAccuracy()
	{
		if(totalNotes != 0 && totalHit != 0)
			songAccuracy = totalHit / totalNotes;
		else
			songAccuracy = 0;
	}

	public var events:Array<Dynamic> = [];

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

	public var currentSettings = Init.trueSettings.copy();

	public function new() {
		super();
		current = this;
	}
	
        public var isWidescreen(get, set):Bool;
    
        private function get_isWidescreen():Bool {
        	return Std.isOfType(FlxG.scaleMode, WideScreenScale) ? cast(FlxG.scaleMode, WideScreenScale).isWidescreen : false;
    	}

    	private function set_isWidescreen(enable:Bool):Bool
    	{
            if (enable == isWidescreen)
            	return isWidescreen;
            if (!Std.isOfType(FlxG.scaleMode, WideScreenScale))
            	FlxG.scaleMode = new WideScreenScale();

            cast(FlxG.scaleMode, WideScreenScale).isWidescreen = enable;

            return enable;
    	}

    	private function get_guiSize():FlxPoint
        {
            if (Std.isOfType(FlxG.scaleMode, WideScreenScale))
            {
                return new FlxPoint(cast(FlxG.scaleMode, WideScreenScale).width, cast(FlxG.scaleMode, WideScreenScale).height);
            }
            else
            {
                return new FlxPoint(1280, 720);
            }
        }
	
	override function create()
	{
		super.create();
		current = this;

		setupCameras();

		// cache "breakfast" from music folder because pause menu!
		FNFAssets.returnAsset(SOUND, AssetPaths.music("breakfast"));

		persistentUpdate = true;
		persistentDraw = true;
		
		FlxG.scaleMode = new WideScreenScale();
		
		set_isWidescreen(true); // fuck the settings, yoshi crafter engine didn't do it for such a fucking obvious reason

		FlxG.sound.music.stop();
		FlxG.sound.list.add(vocals);

		if(SONG == null)
			SONG = SongLoader.getJSON("tutorial", "hard");

		if(SONG.keyCount == null)
			SONG.keyCount = 4;

		if(SONG.keyNumber != null)
			SONG.keyCount = SONG.keyNumber;

		if(SONG.mania != null) {
			switch(SONG.mania) {
				case 1:
					SONG.keyCount = 6;
				case 2:
					SONG.keyCount = 7;
				case 3:
					SONG.keyCount = 9;
				default:
					SONG.keyCount = 4;
			}
		}

		events = [];

		if (SONG.events != null && SONG.events.length > 0) {
			for (event in SONG.events) {
				if(Std.isOfType(event[0], String)) {
					var e:FunkinEvent = {
						scriptToUse: event[0],
						time: event[1],
						parameters: event[2]
					};
					events.push(e);
				} else if(!Std.isOfType(event[0], String)) {
					var time:Float = event[0];
					var array:Array<Array<Dynamic>> = event[1];
					for(item in array) {
						var e:PsychEvent = {
							name: item[0],
							time: time,
							value1: item[1],
							value2: item[2]
						};
						events.push(e);
					}
				}
			}
		}

		DiscordRPC.changePresence(
			'Playing ${SONG.song}',
			'Starting song...'
		);

		Conductor.changeBPM(SONG.bpm);
		Conductor.mapBPMChanges(SONG);
		Conductor.recalculateShit();

		Conductor.position = Conductor.crochet * -5.0;

		scrollSpeed = (Settings.get("Scroll Speed") > 0) ? Settings.get("Scroll Speed") : SONG.speed;
		scrollSpeed /= songMultiplier;

		loadedSong.set("inst", FNFAssets.returnAsset(SOUND, AssetPaths.songInst(SONG.song)));
		
		hasVocals = FileSystem.exists(AssetPaths.songVoices(SONG.song));
		if(hasVocals)
		{
			loadedSong.set("voices", FNFAssets.returnAsset(SOUND, AssetPaths.songVoices(SONG.song)));
			vocals.loadEmbedded(loadedSong.get("voices"), false);
		}

		FlxG.sound.playMusic(loadedSong.get("inst"), 0, false);

		callOnHScripts("create");

		if(!Settings.get("Ultra Performance")) {
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

			stage = new Stage(SONG.stage != null ? SONG.stage : "stage");
			add(stage);

			gf = new Character(stage.gfPosition.x, stage.gfPosition.y, gfVersion);
			gf.scrollFactor.set(0.95, 0.95);
			if(gf.trail != null)
				add(gf.trail);
			add(gf);
			add(stage.inFrontOfGFSprites);

			dad = new Character(stage.dadPosition.x, stage.dadPosition.y, SONG.player2);
			dad.isPlayer = false;
			if(dad.trail != null)
				add(dad.trail);
			add(dad);
			add(stage.inFrontOfDadSprites);
			dads.push(dad);

			bf = new Boyfriend(stage.bfPosition.x, stage.bfPosition.y, SONG.player1);
			bf.flipX = !bf.flipX;
			if(bf.trail != null)
				add(bf.trail);
			add(bf);
			add(stage.foregroundSprites);
			bfs.push(bf);

			// raf istg if you change this shit back
			
			if(dad.curCharacter == gf.curCharacter) {
				dad.goToPosition(gf.x, gf.y);
	
				if (gf.trail != null)
					remove(gf.trail, true);

				remove(gf, true);
				gf.kill();
				gf.destroy();
				gf = null;
			}

			callOnHScripts("createAfterChars");

			//if(stage.script != null)
			//	stage.script.call('createPost');
		}

		// load the song script
		var path:String = 'songs/${actualSongName.toLowerCase()}/script';
		script = new HScript(path);
		script.set("add", this.add);
		script.set("remove", this.remove);
		script.setScriptObject(this);
		script.start();
		
		scripts.push(script);

		// load song scripts
		if(SONG.scripts != null) {
			for(item in SONG.scripts) {
				if(FileSystem.exists(AssetPaths.asset(item))) {
					var script = new HScript(AssetPaths.asset(item), "", true);
					script.set("add", this.add);
					script.set("remove", this.remove);
					script.setScriptObject(this);
					script.start();
					scripts.push(script);
				}
			}
		}

		// load global scripts
		if(FileSystem.exists(AssetPaths.asset('global_scripts'))) {
			for(item in FileSystem.readDirectory(AssetPaths.asset('global_scripts'))) {
				if(item.contains(".")) {
					var real = item;
					for(ext in HScript.hscriptExts)
						real = real.replace(ext, "");

					var path:String = 'global_scripts/$real';
					var script = new HScript(path);
					script.set("add", this.add);
					script.set("remove", this.remove);
					script.setScriptObject(this);
					script.start();
					scripts.push(script);
				}
			}
		}

		// event loading!!! lmao!!!
		if(FileSystem.exists(AssetPaths.asset('psych_events'))) {
			for(item in FileSystem.readDirectory(AssetPaths.asset('psych_events'))) {
				if(item.contains(".")) {
					var real = item;
					for(ext in HScript.hscriptExts)
						real = real.replace(ext, "");

					var path:String = 'psych_events/$real';
					var script = new HScript(path);
					script.set("add", this.add);
					script.set("remove", this.remove);
					script.setScriptObject(this);
					script.start(false);
					scripts.push(script);
				}
			}
		}

		// precache the countdown bullshit
		countdownGraphics = [
			"preready"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(countdownImageLocation+"/preready")),
			"ready"      => FNFAssets.returnAsset(IMAGE, AssetPaths.image(countdownImageLocation+"/ready")),
			"set"        => FNFAssets.returnAsset(IMAGE, AssetPaths.image(countdownImageLocation+"/set")),
			"go"         => FNFAssets.returnAsset(IMAGE, AssetPaths.image(countdownImageLocation+"/go")),
		];

		countdownSounds = [
			"preready"   => FNFAssets.returnAsset(SOUND, AssetPaths.sound(countdownSoundLocation+"/intro3")),
			"ready"      => FNFAssets.returnAsset(SOUND, AssetPaths.sound(countdownSoundLocation+"/intro2")),
			"set"        => FNFAssets.returnAsset(SOUND, AssetPaths.sound(countdownSoundLocation+"/intro1")),
			"go"         => FNFAssets.returnAsset(SOUND, AssetPaths.sound(countdownSoundLocation+"/introGo")),
		];

		countdownPreReady.antialiasing = Settings.get("Antialiasing");
		countdownPreReady.cameras = [camHUD];
		countdownPreReady.alpha = 0;
		add(countdownPreReady);

		countdownReady.antialiasing = Settings.get("Antialiasing");
		countdownReady.cameras = [camHUD];
		countdownReady.alpha = 0;
		add(countdownReady);

		countdownSet.antialiasing = Settings.get("Antialiasing");
		countdownSet.cameras = [camHUD];
		countdownSet.alpha = 0;
		add(countdownSet);

		countdownGo.antialiasing = Settings.get("Antialiasing");
		countdownGo.cameras = [camHUD];
		countdownGo.alpha = 0;
		add(countdownGo);

		if(!inCutscene)
			startCountdown();

		FlxG.camera.zoom = defaultCamZoom;

		UI = new GameplayUI();
		
		for(section in SONG.notes) {
			if(section != null) {
				for(note in section.sectionNotes) {
					var strumTime:Float = note[0];
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
		
		focusCamera(SONG.notes[0].mustHitSection ? "bf" : "dad");
		camFollowPos.setPosition(camFollow.x, camFollow.y);

		callOnHScripts("createPost");
	}

	function getRatingCache(ratingPath:String = "ratings/default")
	{
		return [
			"marvelous"  => FNFAssets.returnAsset(IMAGE, AssetPaths.image(ratingPath+"/marvelous")),
			"sick"       => FNFAssets.returnAsset(IMAGE, AssetPaths.image(ratingPath+"/sick")),
			"good"       => FNFAssets.returnAsset(IMAGE, AssetPaths.image(ratingPath+"/good")),
			"bad"        => FNFAssets.returnAsset(IMAGE, AssetPaths.image(ratingPath+"/bad")),
			"shit"       => FNFAssets.returnAsset(IMAGE, AssetPaths.image(ratingPath+"/shit")),
		];
	}

	function getComboCache(comboPath:String = "combo/default")
	{
		return [
			"marvelous"  => [
				"combo"  => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/combo")),
				"num0"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/num0")),
				"num1"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/num1")),
				"num2"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/num2")),
				"num3"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/num3")),
				"num4"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/num4")),
				"num5"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/num5")),
				"num6"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/num6")),
				"num7"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/num7")),
				"num8"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/num8")),
				"num9"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/marvelous/num9")),
			],
			"default"    => [
				"combo"  => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/combo")),
				"num0"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/num0")),
				"num1"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/num1")),
				"num2"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/num2")),
				"num3"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/num3")),
				"num4"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/num4")),
				"num5"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/num5")),
				"num6"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/num6")),
				"num7"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/num7")),
				"num8"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/num8")),
				"num9"   => FNFAssets.returnAsset(IMAGE, AssetPaths.image(comboPath+"/num9")),
			],
		];
	}

	public var scrollSpeedTween:FlxTween;

	public function getMenuToSwitchTo():Dynamic
	{
		if(isStoryMode)
			return new states.ScriptedState('StoryMenu');
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
		var ret:Dynamic = callOnHScripts("startCountdown", [], false);
		if(ret != HScript.function_stop) {
			countdownTimer = new FlxTimer().start(Conductor.crochet / 1000.0, function(tmr:FlxTimer) {
				if(gf != null)
					gf.dance();

				for(c in dads) {
					if(c != null && c.animation.curAnim != null && !c.animation.curAnim.name.startsWith("sing"))
						c.dance();
				}
		
				for(c in bfs) {
					if(c != null && c.animation.curAnim != null && !c.animation.curAnim.name.startsWith("sing"))
						c.dance();
				}

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
	}

	public function playVideo(name:String, ?callback:Void->Void = null) {
		#if VIDEOS_ALLOWED
		var video:VideoHandler = new VideoHandler();
		video.finishCallback = callback;
		video.playVideo(AssetPaths.video(name));
		#else
		trace("Failed to play video at path: "+AssetPaths.video(name)+" - Your platform doesn't support video playback!");
		callback();
		#end
	}

	public function playVideoSprite(name:String, ?callback:Void->Void = null):VideoSprite {
		#if VIDEOS_ALLOWED
		var video:VideoSprite = new VideoSprite();
		video.finishCallback = callback;
		video.playVideo(AssetPaths.video(name));
		return video;
		#else
		trace("Failed to play video at path: "+AssetPaths.video(name)+" - Your platform doesn't support video playback!");
		callback();
		#end
		return null;
	}

	public function kindaEndSong()
	{
		FlxG.sound.music.stop();
		vocals.stop();
		FlxG.sound.music.time = 0;
		FlxG.sound.playMusic(freakyMenu);
		
		Main.switchState(getMenuToSwitchTo());
	}

	public function finishSong(?ignoreNoteOffset:Bool = false)
	{
		endingSong = true;

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();

		if(vocals != null)
			vocals.stop();

		if(FlxG.sound.music != null)
			FlxG.sound.music.time = 0;

		if((Settings.get("Note Offset") * songMultiplier) <= 0 || ignoreNoteOffset) {
			endSong();
		} else {
			new FlxTimer().start((Settings.get("Note Offset") * songMultiplier) / 1000, function(tmr:FlxTimer) {
				endSong();
			});
		}
	}

	public function endSong()
	{
		if(!inCutscene)
		{
			persistentUpdate = false;
			persistentDraw = true;
			
			endingSong = true;

			var ret:Dynamic = callOnHScripts("endSong", [actualSongName], false);
			
			if(songMultiplier >= 1.0 && !usedPractice && songScore > Highscore.getScore(actualSongName+"-"+currentDifficulty))
				Highscore.setScore(actualSongName+"-"+currentDifficulty, songScore);

			for(object in [UI.timeBarBG, UI.timeBar, UI.timeTxt]) {
				if(object != null) {
					UI.remove(object, true);
					object.kill();
					object.destroy();
					object = null;
				}
			}

			if(UI.healthBarScript != null) {
				UI.healthBarScript.stop();
				UI.healthBarScript = null;
			}
			
			if(UI.timeBarScript != null) {
				UI.timeBarScript.stop();
				UI.timeBarScript = null;
			}
			
			if(ret != HScript.function_stop) {
				if(vocals != null)
					vocals.stop();

				unspawnNotes = [];
				for(note in UI.opponentStrums.notes) {
					UI.opponentStrums.notes.remove(note, true);
					note.destroy();
					note = null;
				}

				for(note in UI.playerStrums.notes) {
					UI.playerStrums.notes.remove(note, true);
					note.destroy();
					note = null;
				}

				if(isStoryMode) {
					storyPlaylist.shift();
					storyScore += songScore;

					if(storyPlaylist.length > 0) {
						actualSongName = storyPlaylist[0];
						SONG = SongLoader.getJSON(storyPlaylist[0], currentDifficulty);
						Main.switchState(new states.PlayState());
					} else {
						if(storyScore > Highscore.getScore(actualWeekName+"-"+currentDifficulty))
							Highscore.setScore(actualWeekName+"-"+currentDifficulty, storyScore);

						FlxG.sound.playMusic(freakyMenu);
						FlxG.sound.music.time = 0;
						
						Main.switchState(getMenuToSwitchTo());
					}
				}
				else {
					FlxG.sound.playMusic(freakyMenu);
					FlxG.sound.music.time = 0;
					Main.switchState(getMenuToSwitchTo());
				}
			}

			callOnHScripts("endSongPost", [actualSongName]);
		}
	}

	var discordRPCTimer:Float = 0.0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		for(c in bfs) {
			if(c != null)
				c.isPlayer = true;
		}

		if(!inCutscene)
		{
			var lerpVal:Float = FlxMath.bound(FlxG.elapsed * 2.4 * cameraSpeed, 0, 1);
			camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		}

		callOnHScripts("update", [elapsed]);

		// gonna be re-enabled once i make the charter
		// if(FlxG.keys.justPressed.SEVEN)
		// 	Main.switchState(new ScriptedState('ChartingState'));

		if(FlxG.keys.justPressed.F6 && !logsOpen)
		{
			logsOpen = true;
			openSubState(new ScriptedSubState('Logs'));
		}

		if(!endingSong && UIControls.justPressed("BACK"))
		{
			persistentUpdate = false;
			persistentDraw = true;
			
			endingSong = true;

			kindaEndSong();
		}

		if(!inCutscene && !endingSong && !UIControls.justPressed("BACK") && UIControls.justPressed("PAUSE"))
		{
			var ret:Dynamic = callOnHScripts("pauseSong", [], false);
			if(ret != HScript.function_stop) {
				logsOpen = false;
				
				persistentUpdate = false;
				persistentDraw = true;

				openSubState(new substates.ScriptedSubState('PauseMenu'));
			}
		}

		if(!inCutscene && !endingSong)
		{
			if(!startedSong)
				Conductor.position += FlxG.elapsed * 1000.0;
			else
				Conductor.position += (FlxG.elapsed * 1000.0) * songMultiplier;

			if(Conductor.position >= 0.0 && !startedSong)
				startSong();
		}

		discordRPCTimer += elapsed;

		if(startedSong && !endingSong)
		{
			if(discordRPCTimer > 1.0) {
				var ret:Dynamic = callOnHScripts("discordRPCUpdate", [], false);
				if(ret != HScript.function_stop) {
					DiscordRPC.changePresence(
						'Playing ${SONG.song} on ${CoolUtil.firstLetterUppercase(currentDifficulty)}',
						'Time remaining: ${FlxStringUtil.formatTime((FlxG.sound.music.length-FlxG.sound.music.time)/1000.0)} / ${FlxStringUtil.formatTime(FlxG.sound.music.length/1000.0)}'
					);
				}
				discordRPCTimer = 0.0;
			}
		}

		if(!customHealth && health <= minHealth)
		{
			health = minHealth;
			gameOver();
		}

		for (event in events) {
			// psych event
			if(event.name != null) {
				if (event.time <= Conductor.position) {
					PsychEventHandler.processEvent(event);
					callOnHScripts("onEvent", [event.name, event.value1, event.value2]);
					events.remove(event);
				}
			}
		}

		spawnNotes();

		if(camZooming) {
			FlxG.camera.zoom = FlxMath.lerp(FlxG.camera.zoom, defaultCamZoom, 0.05 * 60 * FlxG.elapsed);
			camHUD.zoom = FlxMath.lerp(camHUD.zoom, 1, 0.05 * 60 * FlxG.elapsed);
		}

		callOnHScripts("updatePost", [elapsed]);
	}

	public function gameOver() {
		var ret:Dynamic = callOnHScripts("gameOver", [], false);

		if(ret != HScript.function_stop) {
			if(!practiceMode) {
				persistentUpdate = false;
				persistentDraw = false;

				//openSubState(new GameOver(bf.x, bf.y, camFollowPos.x, camFollowPos.y, bf.deathCharacter));
				var deathInfo = {
					x: 700.0,
					y: 360.0,
					camX: camFollowPos.x,
					camY: camFollowPos.y,
					deathChar: "bf-dead"
				};

				if(bf != null)
					deathInfo = {
						x: bf.x,
						y: bf.y,
						camX: camFollowPos.x,
						camY: camFollowPos.y,
						deathChar: bf.deathCharacter
					};
				
				openSubState(new ScriptedSubState('GameOver', [deathInfo.x, deathInfo.y, deathInfo.camX, deathInfo.camY, deathInfo.deathChar]));
			}
		}
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
			while (unspawnNotes.length > 0 && ((unspawnNotes[0].strumTime + (Settings.get("Note Offset") * songMultiplier)) - Conductor.position) < 2500 / scrollSpeed)
			{
				var arrowSkin:String = currentSkin.replace("default", Settings.get("Arrow Skin").toLowerCase());

				var dunceNote:Note = new Note(-9999, -9999, unspawnNotes[0].noteData, false);
				dunceNote.stepCrochet = Conductor.stepCrochet;
				dunceNote.rawStrumTime = unspawnNotes[0].strumTime;
				dunceNote.strumTime = unspawnNotes[0].strumTime + (Settings.get("Note Offset") * songMultiplier);
				dunceNote.mustPress = unspawnNotes[0].mustPress;
				dunceNote.altAnim = unspawnNotes[0].altAnim;
				dunceNote.parent = unspawnNotes[0].mustPress ? UI.playerStrums : UI.opponentStrums;
				dunceNote.loadSkin(arrowSkin);

				var cum:Int = Math.floor(unspawnNotes[0].susLength);
				for(i in 0...cum)
				{
					var susNote:Note = new Note(-9999, -9999, unspawnNotes[0].noteData, true);
					susNote.stepCrochet = Conductor.stepCrochet;
					susNote.rawStrumTime = unspawnNotes[0].strumTime;
					susNote.strumTime = dunceNote.strumTime + (Conductor.stepCrochet * i) + Conductor.stepCrochet;
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
		FlxG.sound.music.pitch = songMultiplier;
		if(hasVocals) {
			vocals.pitch = songMultiplier;
			vocals.volume = 1;
			vocals.play();
		}

		FlxG.sound.music.onComplete = finishSong.bind();

		Conductor.position = 0.0;

		FlxG.sound.music.pause();
		vocals.pause();

		vocals.time = 0;
		FlxG.sound.music.time = 0;

		FlxG.sound.music.play();
		vocals.play();

		callOnHScripts("startSong", [SONG.song]);
	}

	public function focusCamera(onWho:String = "dad")
	{
		switch(onWho.toLowerCase())
		{
			case "dad":
				if(dad == null) {
					camFollow.set(700, 360);
					return;
				};
				camFollow.set(dad.getCamPos().x, dad.getCamPos().y);
			case "bf":
				if(bf == null) {
					camFollow.set(700, 360);
					return;
				}
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

		if(gf != null)
			gf.dance();

		if(gf != null)
			gf.script.call("beatHit", [Conductor.currentBeat]);

		for(c in dads) {
			if(c != null && c.animation.curAnim != null && !c.animation.curAnim.name.startsWith("sing"))
				c.dance();

			if(c != null)
				c.script.call("beatHit", [Conductor.currentBeat]);
		}

		for(c in bfs) {
			if(c != null && c.animation.curAnim != null && !c.animation.curAnim.name.startsWith("sing"))
				c.dance();

			if(c != null)
				c.script.call("beatHit", [Conductor.currentBeat]);
		}

		callOnHScripts("beatHit", [Conductor.currentBeat]);

		if(camZooming && camBumping && Conductor.currentBeat % 4 == 0)
		{
			FlxG.camera.zoom += 0.015;
			camHUD.zoom += 0.03;
		}

		if(startedSong && !endingSong)
			resyncSong();

		callOnHScripts("beatHitPost", [Conductor.currentBeat]);
	}

	override function stepHit()
	{
		super.stepHit();

		callOnHScripts("stepHit", [Conductor.currentStep]);

		if(gf != null)
			gf.script.call("stepHit", [Conductor.currentStep]);

		for(c in dads) {
			if(c != null)
				c.script.call("stepHit", [Conductor.currentStep]);
		}

		for(c in bfs) {
			if(c != null)
				c.script.call("stepHit", [Conductor.currentStep]);
		}

		callOnHScripts("stepHitPost", [Conductor.currentStep]);
	}

	public function clearNotesBefore(time:Float) {
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:UnspawnNote = unspawnNotes[i];
			if(daNote.strumTime - 350 < time)
				unspawnNotes.remove(daNote);
			--i;
		}

		i = UI.opponentStrums.notes.length - 1;
		while (i >= 0) {
			var daNote:Note = UI.opponentStrums.notes.members[i];
			if(daNote.strumTime - 350 < time) {
				daNote.kill();
				UI.opponentStrums.notes.remove(daNote, true);
				daNote.destroy();
			}
			--i;
		}

		i = UI.playerStrums.notes.length - 1;
		while (i >= 0) {
			var daNote:Note = UI.playerStrums.notes.members[i];
			if(daNote.strumTime - 350 < time) {
				daNote.kill();
				UI.playerStrums.notes.remove(daNote, true);
				daNote.destroy();
			}
			--i;
		}
	}

	public function resyncSong()
	{
		if(hasVocals)
		{
			if(!(Conductor.isAudioSynced(FlxG.sound.music) && Conductor.isAudioSynced(vocals)))
			{
				vocals.pause();

				FlxG.sound.music.play();
				Conductor.position = FlxG.sound.music.time;
				vocals.time = FlxG.sound.music.time;
				if(vocals.time < vocals.length)
					vocals.play();
			}
		}
		else
		{
			if(!Conductor.isAudioSynced(FlxG.sound.music))
				Conductor.position = FlxG.sound.music.time;
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

	public function refreshHealthBar() {
		UI.healthBar.createFilledBar(UI.healthColors[0], UI.healthColors[1]);
		UI.healthBar.setRange(minHealth, maxHealth);
	}
	
	public function callOnHScripts(func:String, ?args:Null<Array<Dynamic>>, ignoreStops = true):Dynamic
	{
		var returnVal:Dynamic = HScript.function_continue;

		for(script in scripts) {
			if(script == null) continue;

			var ret:Dynamic = script.call(func, args);

			if(ret == HScript.function_stop_script && !ignoreStops)
				break;

			var bool:Bool = ret == HScript.function_continue;
			if(!bool)
				returnVal = cast ret;
		}

		return returnVal;
	}

	override function destroy()
	{
		for(script in scripts) {
			script.stop();
		}
		scripts = [];
		current = null;
		super.destroy();
	}
}
