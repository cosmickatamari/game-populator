@{
  Sources = @(
#    Standard consoles only. Each Name must match console-names.json.
#    Other categories — hacks-sources.psd1 + hacks-names.json; trans-sources.psd1 + trans-names.json;
#    addons-sources.psd1 + addons-names.json.
#    @{
#        Name = 'Acetronic MPU 1000'
#        SourcePath = '\\server\share\VC4000'
#    }
#    @{
#        Name = 'Atari 2600'
#        SourcePath = '\\server\share\Atari2600'
#    }
#    @{
#        Name = 'Atari 5200'
#        SourcePath = '\\server\share\Atari5200'
#    }
#    @{
#        Name = 'Atari 7800'
#        SourcePath = '\\server\share\Atari7800'
#    }
#    @{
#        Name = 'Atari Lynx'
#        SourcePath = '\\server\share\AtariLynx'
#    }
#    @{
#        Name = 'Bally Astrocade'
#        SourcePath = '\\server\share\Astrocade'
#    }
#    @{
#        Name = 'BBC Bridge Companion'
#        SourcePath = '\\server\share\BBCBridgeCompanion'
#    }
#    @{
#        Name = 'Bandai Super Vision 8000'
#        SourcePath = '\\server\share\SuperVision8000'
#    }
#    @{
#        Name = 'Bandai WonderSwan'
#        SourcePath = '\\server\share\WonderSwan'
#    }
#    @{
#        Name = 'Bandai WonderSwan Color'
#        SourcePath = '\\server\share\WonderSwan'
#    }
#    @{
#        Name = 'Benesse Pocket Challenge V2'
#        SourcePath = '\\server\share\PocketChallengeV2'
#    }
#    @{
#        Name = 'Bit Corporation - Gamate'
#        SourcePath = '\\server\share\Gamate'
#    }
#    @{
#        Name = 'Casio PV-1000'
#        SourcePath = '\\server\share\Casio_PV-1000'
#    }
#    @{
#        Name = 'Coleco ColecoVision'
#        SourcePath = '\\server\share\Coleco'
#    }
#    @{
#        Name = 'Emerson Arcadia 2001'
#        SourcePath = '\\server\share\Arcadia'
#    }
#    @{
#        Name = 'Entex Adventure Vision'
#        SourcePath = '\\server\share\AVision'
#    }
#    @{
#        Name = 'Epoch Co Super Cassette Vision'
#        SourcePath = '\\server\share\SCV'
#    }
#    @{
#        Name = 'Fairchild Channel F'
#        SourcePath = '\\server\share\ChannelF'
#    }
#    @{
#        Name = 'General Consumer Electronics - Vectrex'
#        SourcePath = '\\server\share\Vectrex'
#    }
#    @{
#        Name = 'Interton Video Computer 4000'
#        SourcePath = '\\server\share\VC4000'
#    }
#    @{
#        Name = 'Magnavox Odyssey 2'
#        SourcePath = '\\server\share\Odyssey2'
#    }
#    @{
#        Name = 'Mattel Intellivision'
#        SourcePath = '\\server\share\Intellivision'
#    }
#    @{
#        Name = 'Sega Genesis - Mega Drive'
#        SourcePath = '\\server\share\MegaDrive'
#    }
#    @{
#        Name = 'NEC CD-ROM² - Super CD-ROM²'
#        SourcePath = '\\server\share\TGFX16-CD'
#    }
#    @{
#        Name = 'NEC PC Engine - TurboGrafx-16'
#        SourcePath = '\\server\share\TGFX16'
#    }
#    @{
#        Name = 'NEC SuperGrafx'
#        SourcePath = '\\server\share\TGFX16'
#    }
#    @{
#        Name = 'Nichibutsu My Vision'
#        SourcePath = '\\server\share\MyVision'
#    }
#    @{
#        Name = 'Nintendo 64'
#        SourcePath = '\\server\share\N64'
#    }
#    @{
#        Name = 'Nintendo Entertainment System'
#        SourcePath = '\\server\share\NES'
#    }
#    @{
#        Name = 'Nintendo Family Computer Disk System'
#        SourcePath = '\\server\share\NES'
#    }
#    @{
#        Name = 'Nintendo Game & Watch'
#        SourcePath = '\\server\share\GameNWatch'
#    }
#    @{
#        Name = 'Nintendo Game Boy'
#        SourcePath = '\\server\share\Gameboy'
#    }
#    @{
#        Name = 'Nintendo Game Boy Advance'
#        SourcePath = '\\server\share\GBA'
#    }
#    @{
#        Name = 'Nintendo Game Boy Color'
#        SourcePath = '\\server\share\Gameboy'
#    }
#    @{
#        Name = 'Nintendo Pokemon Mini'
#        SourcePath = '\\server\share\PokemonMini'
#    }
#    @{
#        Name = 'Nintendo Super Game Boy (GB original)'
#        SourcePath = '\\server\share\SGB-GB'
#    }
#    @{
#        Name = 'Nintendo Super Game Boy (GBC original)'
#        SourcePath = '\\server\share\SGB-GBC'
#    }
#    @{
#        Name = 'Occitane OC2000'
#        SourcePath = '\\server\share\VC4000'
#    }
#    @{
#        Name = 'Philips Compact Disc-Interactive'
#        SourcePath = '\\server\share\CD-i'
#    }
#    @{
#        Name = 'Philips Videopac G7000'
#        SourcePath = '\\server\share\Odyssey2'
#    }
#    @{
#        Name = 'Sega 32X'
#        SourcePath = '\\server\share\S32x'
#    }
#    @{
#        Name = 'Sega CD'
#        SourcePath = '\\server\share\MegaCD'
#    }
#    @{
#        Name = 'Sega Game Gear'
#        SourcePath = '\\server\share\SMS'
#    }
#    @{
#        Name = 'Sega Master System'
#        SourcePath = '\\server\share\SMS'
#    }
#    @{
#        Name = 'Sega Saturn'
#        SourcePath = '\\server\share\Saturn'
#    }
#    @{
#        Name = 'Sega SG-1000'
#        SourcePath = '\\server\share\SG1000'
#    }
#    @{
#        Name = 'SNK Neo Geo AES & MVS'
#        SourcePath = '\\server\share\NeoGeo'
#    }
#    @{
#        Name = 'SNK Neo Geo CD'
#        SourcePath = '\\server\share\NeoGeo-CD'
#    }
#    @{
#        Name = 'SNK Neo Geo Pocket'
#        SourcePath = '\\server\share\NeoGeoPocket'
#    }
#    @{
#        Name = 'SNK Neo Geo Pocket Color'
#        SourcePath = '\\server\share\NeoGeoPocket'
#    }
#    @{
#        Name = 'Sony PlayStation'
#        SourcePath = '\\server\share\PSX'
#    }
#    @{
#        Name = 'Super Nintendo Entertainment System'
#        SourcePath = '\\server\share\SNES'
#    }
#    @{
#        Name = 'Super Nintendo Entertainment System - BS-X Satellaview'
#        SourcePath = '\\server\share\SNES'
#    }
#    @{
#        Name = 'VTech CreatiVision - Dick Smith Wizzard'
#        SourcePath = '\\server\share\CreatiVision'
#    }
#    @{
#        Name = 'Watara SuperVision'
#        SourcePath = '\\server\share\SuperVision'
#    }
  )
}
