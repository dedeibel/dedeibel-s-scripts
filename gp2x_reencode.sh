#!/bin/bash

#
# reencode Version 0.14
#
# A script to make life with mencoder easier. It's main
# purpose is to encode videos to be used on a handheld like
# the gp2x but it can also be used for better qualities
#
# Requirements:
#       mencoder with support for mp3lame, lavc or xvid
#       check with "mencoder -ovc help" and "mencoder -oac help"
#
# Author:
#       Benjamin Peter <dedeibel at arcor.de>
#
# Please feel free to contact me in case of any bugs or
# usefull comments. You may change this script as you like
# but if you have major improvements it would be nice to hear
# from you.
#
#
# Changelog:
#
# 0.14
#    - Removed "subcmp=3:mbcmp=3" from lavc codec options since they
#      are causing a segfault with the latest mplayer version (> 1.0pre7)
#
#    By Tuxzilla <nemesisds at yahoo.com>
#    - Added option "-y | acopy" to copy original audio without
#      recompressing
#    - Added option "-x | crop" to crop black bars
#
# 0.13
#    - Bugfix: When deinterlacing was requested, mencoder fails
#      to scale the video to the correct frame size. Thanks to
#      Neil Hoggarth <njh at hoggarth.me.uk>
#
# 0.12
#    - Added option "-v | volume" to adjust the volume boost
#      (thanks to Dittboy)
#    - Deinterlacing with fd/ffmpegdeint as default methode
#      and option "-g | deint" to enable deinterlacing added
#
# 0.11
#    - Single pass encoding is now default
#    - Added smaller help making it easier to keep track of options
#
# 0.10
#    - Added multiple input files support
#    - You can now also specify an output directory with -o
#    - Input files will be checked for existance
#    - Added troubleshooting section
#    - More comments
#    - Unimportant problem with multi pass enc fixed
#
# 0.9
#    - Fixed a problem with space characters
#    - Added sample functionality
#    - Renamed audio samplerate from sample to arate
#
# 0.8
#    - Initial release
#
#
#
# Examples:
#
#  Encode two files with standard options
#    reencode in justdoit.avi anotherFile.mpg
#
#  Encode all mpg files in the current dir to the /tmp directory
#    reencode in *.mpg -d /tmp
#
#  The same but with long options and '-' input list termination
#    reencode in *.mpg - out /tmp
#
#  Encode chapter 4 to 8 from title 1 on DVD to a specified file
#    reencode -d 1 out /tmp/mymovie.avi extra -chapter 4-8
#
#  Encode a sample from minute 45 on DVD title 2
#    reencode dvd 2 -l 45m
#
#  Encode DVD title 1 and crop the black bars
#    reencode -d 1 -x 720:544:0:16
#
#  Encode a file with xvid and 300kbps in cartoon mode while including the
#  specified subtitles
#    reencode -i ~/greatmovie.mpg -sub ~/sub.srt codec xvid -r 300 cartoon
#
#
#
# Troubleshooting:
#
# Q: I want to use xvid but there is a message like:
#       xvidencopts is not an MEncoder option
#
# A: Make sure you have xvid support compiled into mencoder
#    check "mencoder -ovc help" to list the availlable codecs
#
#
#
# Q: When using the sample function I get errors like:
#       reencode: line 482: 21217 Floating point exceptionmencoder $options
#       $audioCodec ${videoCodec}${passOption} "$currentInfile" -o "$currentOutfile" 2>&1
#        * File NOT successfully encoded"
#
# A: The problem here is that the video you wanted to encode is smaller than
#    the start time of the sample + 3 Minutes. If the Video is that short you
#    may not need a sample, right?
#
#
# Q: When encoding one or more files I get an error like:
#         ERROR: input file 'out' does not exist
#
# A: You might have forgotten to specify a '-' or an option beginning with a
#    dash as the next option after 'in' or '-i'
#
#    Wrong: reencode in movie.avi out /tmp/
#    Right: reencode in movie.avi - out /tmp/
#    Right: reencode in movie.avi -o /tmp/
#    Right: reencode out /tmp in movie.avi
#
#
# Q: I get allways messages like '31 duplicate frame(s)!'
#
# A: This is a problem of mencoder it seems to have a problem with some input
#    formats most of the time this is no problem but sometimes if there are
#    too many of these this can lead to a faster playing movie.
#



# Default output dir if no output file is specified, PLEASE CHANGE
outputDir="/media/movies/gp2x-ready"




# Default values
codec="lavc"
scale="320:-3"
subtitleFile=""

# Deinterlacing
declare -i deinterlace=0
deinterlaceFilter="fd"

declare -i videoBitrate=250
declare -i audiocopy=0
declare -i audioBitrate=64
declare -i audioVolume=0
declare -i samplerate=22050
declare -i pass=1

dvd=""
crop=""
extraOptions=""

sampleStart=""
# [[hh:]mm:]ss
sampleDuration="2:00" 

# Xvid specific options
declare -i cartoon=0
quant_type="mpeg"



# Array of all specified infiles
infiles=()

# The specified output file or directory, if there is more than one
# inputfile an output file is invalid.
outfile=""

# Set by the codec, (e.g. for lavc it is "vpass")
videoCodecPasscmnd=""

# Parameters for mencoder
options=""
audioCodec=""
videoCodec=""
subtitle=""

# Set for each input file that is processed
currentInfile=""
currentOutfile=""

# Statistic stuff
declare -i starttime=0
declare -i stoptime=0


#
# Prints a short help about the usage
#
printShortHelp()
{
    echo "reencode OPTION VALUE ... [-e|extra VALUES ...]"
    echo ""
    echo "OPTIONS [default]:"
    echo "-i | in       Infiles (Has to be at the end or followed by a '-')"
    echo "-d | dvd      Encode from a DVD (specify titles)"
    echo "-o | out      Outfile or directory [<infile>-small.avi]"
    echo ""
    echo "-c | codec    Codec lavc,xvid [lavc]"
    echo "-r | rate     Bitrate [250]"
    echo "-s | scale    Scale [320:-3]"
    echo "-a | audio    Audio bitrate [64]"
    echo ""
    echo "-h | help     List more help"
}

#
# Prints longer help about the usage
#
printHelp()
{
    echo "reencode OPTION VALUE ... [-e|extra VALUES ...]"
    echo ""
    echo "OPTIONS [default]:"
    echo "-i | in       Infiles (Has to be at the end or followed by a '-')"
    echo "-d | dvd      Encode from a DVD (specify titles)"
    echo "-o | out      Outfile or directory [<infile>-small.avi]"
    echo ""
    echo "-c | codec    Codec lavc,xvid [lavc]"
    echo "-r | rate     Bitrate [250]"
    echo "-x | crop     Try 'mplayer file.avi -vf cropdetect' to get dimentions"
    echo "-s | scale    Scale [320:-3]"
    echo "-p | pass     Passes [1]"
    echo "-g | deint    Use deinterlacing"
    echo "-t | cartoon  Use cartoon mode (xvid only)"
    echo ""
    echo "-y | acopy    Copy audio without recompressing"
    echo "-a | audio    Audio bitrate [64]"
    echo "-m | arate    Audio samplerate [22050]"
    echo "-v | volume   Audio volume gain (db) [0]"
    echo ""
    echo "-l | sample   Get a sample, specify starttime (Nh or Nm or hh:mm:ss)"
    echo "-u | sub      Subtitle file [none]"
    echo "-e | extra    Extra options for mencoder (Has to be the last option)"
    echo ""
    echo "Examples:"
    echo "    reencode -d 1-2 out /tmp/mymovie.avi extra -chapter 4-8"
    echo "    reencode dvd 2 -l 45m"
    echo "    reencode -i ~/movie.mpg -sub ~/sub.srt codec xvid -r 300 cartoon"
    echo "    reencode in justdoit.avi anotherFile.mpg"
}

#
# Prints information about the current options that
# are set
#
printStatus()
{
    echo ""

    # List DVD title or infiles
    if [ -n "$dvd" ]; then
        echo "DVD.title.....: $dvd"
    else
        echo "Infiles.......: ${infiles[@]}"
    fi

    # Print outputfile if is not empty and there is only one input file
    if [ -n "$outfile" -a ${#infiles[@]} -eq 1 ]; then
        echo "Outfile.......: $outfile"
    else
        echo "Outdirectory..: $outputDir"
    fi

    echo "Codec.........: $codec"

    # Only availlable for xvid
    if [ "$codec" == "xvid" ]; then
        echo "    Cartoon...: $cartoon"
        echo "    QuantType.: $quant_type"
        echo ""
    fi

    echo "Bitrate.......: $videoBitrate"

    # Show only if not set to default
    if [ $deinterlace -ne 0 ]; then
        echo "Deinterlacing.: ${deinterlaceFilter}"
    fi

    echo "Audiobitrate..: $audioBitrate"

    # Show only if not set to default
    if [ "$audioVolume" -ne 0 ]; then
        echo "Audio.vol.Gain: ${audioVolume}db"
    fi

    echo "Samplerate....: $samplerate"
    echo "Passes........: $pass"
    echo "Scale.........: $scale"

    if [ -n "$subtitleFile" ]; then
        echo "Subtitles.....: $subtitleFile"
    fi

    if [ -n "$extraOptions" ]; then
        echo "Extra.options.: $extraOptions"
    fi

    if [ -n "$sampleStart" ]; then
        echo ""
        echo "Sample........: $sampleStart + $sampleDuration"
    fi

    echo "----------------------------------"
    echo ""
}

#
# A countdown, gives time to read the mencoder command
#
countdown()
{
    echo -n "Starting "; sleep 1
    echo -n "."; sleep 1
    echo -n "."; sleep 1
    echo    "."; sleep 1
}

#
# Checks if the input files or dvd option is correct
#
# If the dvd option was specified it sets the infiles to dvd://
#
checkInfile()
{
    # If there were no input files provided
    if [ ${#infiles[@]} -lt 1 ]; then
        # And no dvd option
        if [ -z "$dvd" ]; then
            echo "ERROR: No infile or dvd specified."
            exit 1
        else
            infiles[0]="dvd://${dvd}"
        fi
    else 
        if [ -n "$dvd" ]; then
            echo "ERROR: infiles and dvd cannot be used at the same time"
            exit 1
        fi

    # Check if all input files exist
    i=0
    while [ $i -lt ${#infiles[@]} ]; do
        if [ ! -f "${infiles[$i]}" ]; then
            echo "ERROR: input file '${infiles[$i]}' does not exist"
            echo "(make sure you have a '-' after the infiles or put them at the end)"
            exit 1
        fi

        let "i=i+1"
    done

    fi
}

#
# Checks if the output directory exist and creates it if necessary
#
checkOutputDirectory()
{
    if [ ! -e "$outputDir" ]; then
        mkdir "$outputDir"

        if [ $? -ne 0 ]; then
            echo "ERROR: Could not create output directory '$outputDir'"
            exit 1
        else
            echo "NOTE: Created output directory '$outputDir'"
        fi
    else
        if [ ! -d "$outputDir" ]; then
            echo "ERROR: Path '$outputDir' is not a directory"
            exit 1
        fi
    fi
}

#
# Checks if there was an output directory specified and overrides
# the default output directory
#
checkOutfile()
{
    if [ -d "$outfile" ]; then
        outputDir="$outfile"
        outfile=""
    fi

    # An output file and more than one input file is not allowed
    if [ -n "$outfile" -a ${#infiles[@]} -gt 1 ]; then
        echo -n "NOTE: Ignoring output file, since you specified more"
        echo " than one input file"
        output=""
    fi
}

#
# Sets "currentOutfile" depending on the value in "currentInfile"
#
getOutputFile()
{
    # One input file, nonempty outputfile, that one is easy
    if [ ${#infiles[@]} -eq 1 -a -n "$outfile" ]; then
        currentOutfile="$outfile"
    # more than one input file
    else
        postfix="small"
        checkOutputDirectory

        # We want to create a sample, different postfix
        if [ -n "$sampleStart" ]; then
            postfix="sample"
        fi
        
        if [ -n "$dvd" ]; then
            date=`date +"%s"`
            currentOutfile="${outputDir}/DVD-${date}-${postfix}.avi"
        else
            # get the basename and remove file extension
            basename=`basename "$currentInfile" | sed -re 's/\..{2,4}$//'`
            currentOutfile="${outputDir}/${basename}-${postfix}.avi"
        fi
    fi
}


#
# Puts the 'options' for mencoder together, these are
# common options like scale oder start position
#
assembleOptions()
{
    options="-vf "
    comma="" # If we need a comma for the next filter option

    # If deinterlacing is not disabled
    if [ $deinterlace -ne 0 ]; then
        options="${options}${comma}pp=${deinterlaceFilter}"
        comma=","
    fi
    
    # If cropping is enabled
    if [ -n "$crop" ];then
        options="${options}${comma}crop=$crop"
        comma=","
    fi

    # Scale
    options="${options}${comma}scale=$scale"

    # If the audio volume should be increased
    if [ $audioVolume -ne 0 ]; then
        options="$options -af volume=${audioVolume}:0"
    fi

    # There were extra options specified, append them
    if [ -n "$extraOptions" ]; then
        options="$options $extraOptions"
    fi

    # Create a sample
    if [ -n "$sampleStart" ]; then
        sampleStart=${sampleStart/h/:00:00}
        sampleStart=${sampleStart/m/:00}
        
        options="$options -ss $sampleStart -endpos $sampleDuration"
    fi
}

#
# Here are the "audioCodec" options assembled
#
assembleAudioCodec()
{
    if [ "$audiocopy" -eq 1 ]; then
        audioCodec="-oac copy"
    else
        audioCodec="-oac twolame -srate $samplerate -twolameopts br=${audioBitrate}"
    fi
}

#
# Puts the 'videoCodec' variable together, it passes
# this task to a function for each codec
#
assembleVideoCodec()
{
    case $codec in
        xvid) getXvidCodec;;
        lavc) getLavcCodec;;
        *) echo "ERROR: Unknown codec '$codec'"; exit 1;;
    esac
}

#
# Sets 'videoCodec' for encoding with xvid
#
getXvidCodec()
{
    videoCodecPasscmnd="pass"
    videoCodec="-ovc xvid -xvidencopts bitrate=${videoBitrate}:autoaspect"

    #
    # Enable cartoon mode
    #
    if [ "$cartoon" -eq 1 ]; then
         videoCodec="${videoCodec}:cartoon"
    fi

    #
    # h263 is meant to better at low bitrates
    #
    if [ $videoBitrate -lt 400 ]; then
        quant_type="h263"
    else
        quant_type="mpeg"
    fi

    videoCodec="${videoCodec}:quant_type=${quant_type}"

    #
    # Improves quality at the cost of encoding time
    #
    videoCodec="${videoCodec}:chroma_opt:vhq=1"
}

#
# Sets 'videoCodec' for encoding with lavc (divx)
#
getLavcCodec()
{
    videoCodecPasscmnd="vpass"
    videoCodec="-ovc lavc -lavcopts vbitrate=${videoBitrate}"

    if [ $cartoon -eq 1 ]; then
        echo "NOTE: cartoon mode not supported by lavc!"
    fi

    videoCodec="${videoCodec}:v4mv:mbd=2:trell:cmp=2:vhq=1"
    options="$options -ffourcc DX50" # Otherwise gp2x won't recognize it
}

#
# Sets the 'subtitle' variable if there was a subtitle file prived
#
assembleSubtitle()
{
    if [ -n "$subtitleFile" ]; then
        subtitle="-sub $subtitleFile"
    else
        subtitle=""
    fi
}

#
# Prints the current input file, output file, pass,
# number of passes and the date
#
# Paramters:
#    currentPass numberOfPasses
#
printPass()
{
    currentPass=$1
    passes=$2
    date=`date`

    echo ""
    echo "********"
    echo "******** File '$currentInfile' => '$currentOutfile'"
    echo "********"
    echo "******** Pass (${currentPass}/${passes}) [$date]"
    echo "********"
    echo ""
}

#
# Calls mencoder with all the options that were assembled before
#
# Parameter:
#     (optional) passNumber
#
doPass()
{
    passOption=""

    if [ -n "$1" ]; then
        passOption=":${videoCodecPasscmnd}=$1"
    fi

    #
    # GET TO WORK!
    #
    echo "Running:"
    echo "mencoder $options $audioCodec ${videoCodec}${passOption} \"$currentInfile\" -o \"$currentOutfile\""
    echo ""

    countdown
    mencoder $options $audioCodec ${videoCodec}${passOption} "$currentInfile" -o "$currentOutfile" 2>&1

    if [ $? -ne 0 ]; then
        echo "* File NOT successfully encoded"
        exit 2
    fi
}

#
# Note the starttime of the script
#
scriptStart()
{
    starttime=`date +"%s"`
}

#
# Display the runtime of the script
#
scriptEnd()
{
    stoptime=`date +"%s"`
    declare -i tmptime

    let "tmptime = stoptime - starttime"
    let "hours = (tmptime / 3600)"

    let "tmptime -= (hours * 3600)"
    let "minutes = tmptime / 60"
    
    echo ""
    echo "* Done after ${hours}h and ${minutes}m"
}

#
# Executes all necessary passes
#
encodeVideo()
{
    if [ $pass -eq 1 ]; then
        printPass 1 1
        doPass
    else
        if [ $pass -eq 2 ]; then
            printPass 1 2
            doPass 1
    
            printPass 2 2
            doPass 2
        else
            printPass 1 $pass
            doPass 1
    
            for passnr in `seq 2 $pass`; do
                printPass $passnr $pass
                doPass 3
            done
        fi
    fi
}

# main

scriptStart

if [ "$#" -lt 1 ]; then
    printShortHelp
    exit 1
fi

# While there are parameters left
while [ -n "$1" ]; do
    case $1 in
        -i | in) shift;
            firstChar=${1:0:1} # get the first character
        
            # While there is no "-" as first char of a parameter
            while [ -n "$firstChar" -a "-" != "$firstChar" ]; do
                infiles[${#infiles[@]}]=$1;
                shift

                firstChar=${1:0:1}
            done

            # "-" as parameter serves only as delimiter, get it off the list
            if [ "$1" == "-" ]; then
                shift
            fi
        ;;
        -d | dvd)      shift; dvd=$1;             shift ;;
        -o | out | of) shift; outfile=$1;         shift ;;

        -c | codec)    shift; codec=$1;           shift ;;
        -r | rate)     shift; videoBitrate=$1;    shift ;;
        -p | pass)     shift; pass=$1;            shift ;;
        -x | crop)     shift; crop=$1;            shift ;;
        -s | scale)    shift; scale=$1;           shift ;;
        -t | cartoon)  shift; cartoon=1                 ;;
        -g | deint)    shift; deinterlace=1             ;;

        -y | acopy)    shift; audiocopy=1               ;;
        -a | audio)    shift; audioBitrate=$1;    shift ;;
        -m | arate)    shift; samplerate=$1;      shift ;;
        -v | volume)   shift; audioVolume=$1;     shift ;;

        -l | sample)   shift; sampleStart=$1;     shift ;;
        -u | sub)      shift; subtitleFile=$1;    shift ;;
        -e | extra)
            shift; extraOptions=$@;
            while [ -n "$1" ]; do
                shift;
            done
        ;;
        -h | help) printHelp; exit ;;
        *) echo "ERROR: Unknown command '$1'"; exit 1;;
    esac
done

checkInfile
checkOutfile
assembleOptions
assembleAudioCodec
assembleVideoCodec
assembleSubtitle
printStatus

i=0
while [ $i -lt ${#infiles[@]} ]; do
    # Set the filename that should be encoded
    currentInfile=${infiles[$i]}
    getOutputFile

    encodeVideo

    let "i=i+1"
done

scriptEnd

# end of main

