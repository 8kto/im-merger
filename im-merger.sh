#!/bin/bash
#===============================================================================
#
#          FILE:  im-merger.sh
#
#   DESCRIPTION:  Слияние изображений в заданной папке. Справка ниже в коде.
#
#  REQUIREMENTS:  ImageMagick
#          BUGS:  ---
#         NOTES:  Строки помеченные [EDIT ON NECESSITY] влияют на логику
#                 скрипта.
#===============================================================================

#-------------------------------------------------------------------------------
# Информация
#-------------------------------------------------------------------------------
AUTHOR='Okto'
VERSION='1.0.1'
LINK='http://axisful.info'
LICENSE='GNU GPLv3'

HELP=$( cat <<EOF
    im-merger $VERSION $AUTHOR <$LINK>
    $LICENSE
    Слияние изображений в заданной папке. 
    Предполагается, что все изображения — одинаковых размеров.
    Опции:
        -h|--help
            Эта справка.
        -v|--version
            Версия скрипта.
        -d|--input-directory <DIR>
            Директория с изображениями (не будут изменены).
        -o|--output-file <FILE> [layers_merge.png]
            Куда сохранять итоговый файл.
        -b|--background <STRING> [none]
            Цвет фона для итогового изображения.  
        -w|--tile-width <NUMBER>
            Ширина изображения.
        -h|--tile-height <NUMBER>
            Высота изображения.
        -mc|--max-col <NUMBER>
            Количество изображений в ряду. 
            Количество рядов вычисляется автоматически, исходя из этого параметра
            и общего количества файлов.
        --merge-each-row <NUMBER> [10]
            Сливать каждые <NUMBER> ряды за раз. 
        -e|--extra-args <STRING>
            Дополнительные аргументы для convert.   
EOF
)

#===============================================================================
# Значения параметров по умолчанию и внутренние переменные
#===============================================================================
_MAX_COL=0
_FWIDTH=0
_FHEIGHT=0
merge_each_row=10
output_file='layers_merge.png'
background='none'
extra_args='+repage'

row=0
col=0
icol=0
output=''
tmp_row_prefix='.im_merger_tmp_row_'
remove_list=''

#-------------------------------------------------------------------------------
# Разбираем параметры скрипта
#-------------------------------------------------------------------------------
while [ "${1+isset}" ]; do
    case "$1" in
        -d|--input-directory)
            dir=$2
            shift 2
        ;;
        -o|--output-file)
            output_file=$2
            shift 2
        ;;
        -b|--background)
            background=$2
            shift 2
        ;;
        -w|--tile-width)
            _FWIDTH=$2
            shift 2
        ;;
        -h|--tile-height)
            _FHEIGHT=$2
            shift 2
        ;;
        -mc|--max-col)
            _MAX_COL=$2
            shift 2
        ;;
        -e|--extra-args)
            extra_args=$2
            shift 2
        ;;
        --merge-each-row)
            merge_each_row=$2
            shift 2
        ;;
        -v|--version)
            echo $VERSION
            exit 0
        ;; 
        *)
          echo "$HELP"
          exit 0
        ;;
    esac
done

#-------------------------------------------------------------------------------
# Проверка на корректность введёных параметров
#-------------------------------------------------------------------------------
if ! [ -d $dir ]; then
    echo "Ошибка: Директория $dir не существует."
    exit 1
fi
if [ $_FWIDTH -le 0 -o $_FHEIGHT -le 0 -o $_MAX_COL -le 0 ]; then
    echo "Ошибка: Проверьте значения геометрических параметров."
    exit 1
fi
if [ $merge_each_row -le 0 ]; then
    echo "Ошибка: Укажите значение --merge-each-row больше нуля."
    exit 1
fi

#===============================================================================
# Процедуры
#===============================================================================

#-------------------------------------------------------------------------------
# Вызвать convert, вывести команду перед выполнением
# $1 Список файлов с гемоетрическими параметрами
# $2 Выходной файл для слитых изображений
#-------------------------------------------------------------------------------
call_convert()
{
    command="convert $1 -background $background -layers merge $extra_args $2"
    echo $command
    echo
    $($command)
}

#===============================================================================
# LOGIC
# +dx*file_width +dy*file_height
#===============================================================================

# Сливаем все файлы в ряду
# Ряды сохраняем в директории скрипта с именами вида $tmp_row_prefix + ROWNUMBER
echo '==== Создание временных рядов'
for file in $( find $dir -name "*.png" | sort ); do # [EDIT ON NECESSITY]
    # Ряд окончен     
    if [ $col -eq $_MAX_COL ]; then
        col=0
        call_convert "$output" "$tmp_row_prefix$row"
        row=$(($row + 1))
        output=''
    fi
    output=$output"-page +$(($col * $_FWIDTH))+$(($row * $_FHEIGHT)) $file "

    col=$(($col + 1)) 
done

# unlogic (Вызов convert для последнего ряда)
call_convert "$output" "$tmp_row_prefix$row"

# Сливаем все полученные ряды
output=''
row=0

echo '==== Слияние временных рядов'
for tmp_row in $( find . -name "$tmp_row_prefix*" | sort -n -t _ -k 5 ); do # [EDIT ON NECESSITY]
    if [ $row -ne 0 -a $(($row % $merge_each_row)) -eq 0 ]; then
        call_convert "$output" "$output_file"
        output="-page +0+0 $output_file "
    fi
        
    output=$output"-page +0+$(($row * $_FHEIGHT)) $tmp_row "
    remove_list=$remove_list"$tmp_row "
    row=$(($row + 1))
done

call_convert "$output" "$output_file"

# Удаляем временные ряды
echo '==== Удаление временных рядов'
rm $remove_list

exit 0


