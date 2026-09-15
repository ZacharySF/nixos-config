#!/bin/sh
capacity=$(cat /sys/class/power_supply/BAT0/capacity)
status=$(cat /sys/class/power_supply/BAT0/status)

if [ "$status" = "Charging" ]; then
  icon="󰂄 "
elif [ "$capacity" -le 10 ]; then
  icon="󰁺"
elif [ "$capacity" -le 25 ]; then
  icon=" "
elif [ "$capacity" -le 50 ]; then
  icon=" "
elif [ "$capacity" -le 75 ]; then
  icon=" "
else
  icon=" "
fi

echo "$icon $capacity%"
