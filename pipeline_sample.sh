#!/usr/bin/env bash

#./pipeline_sample.sh data/testdata_all data/testdata_all/parent_children.sorted.tab data/asr.english data/video.ocr/en.cleaned.csv data/video.ocr/ru.cleaned.csv

######################################################
# Arguments
######################################################
# input root path
data_root=$1
output_dir=$2
parent_child_tab_path=$3
asr_en_path=$4
ocr_en_path=$5
ocr_ru_path=$6
sorted=1

# data folder that specified with language
data_root_ltf=${data_root}/ltf
data_root_rsd=${data_root}/rsd
data_root_result=${output_dir}
output_ttl=${data_root_result}/kb/ttl
log_dir=${output_dir}/log


#####################################################################
# set up services, please reserve the the following ports and ensure that no other programs/services are occupying these ports:
# `27017`, `2468`, `5500`, `5000`, `5234`, `9000`, `6001`, `6101` and `6201`.
#####################################################################
mkdir -p ${log_dir}
#sh set_up.sh > ${log_dir}/log_set_up.txt
sh set_up.sh
echo "set_up successfully"
#docker ps


####################################################################
# preprocessing, including language detection, ASR/OCR preprcessing
####################################################################
docker run --rm -v ${data_root}:${data_root} -v ${data_root_result}:${data_root_result} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /preprocessing/preprocess_detect_languages.py ${data_root_rsd} ${data_root_ltf} ${data_root_result}
sh preprocess_asr_ocr.sh ${data_root_result} ${asr_en_path} ${ocr_en_path} ${ocr_ru_path}

wait

#####################################################################
# extraction, including entity, relation, event
#####################################################################
for lang in 'en' 'ru' 'uk'
do
    for datasource in '' '_asr' '_ocr'
    do
        (
            data_root_lang=${data_root_result}/${lang}${datasource}
            if [ -d "${data_root_lang}/ltf" ]
            then
                sh preprocess.sh ${data_root_lang} ${lang} ${parent_child_tab_path} ${sorted}
                sh pipeline_sample_${lang}.sh ${data_root_lang} ${parent_child_tab_path} ${lang} ${datasource}
            else
                echo "No" ${lang}${datasource} " documents in the corpus. Please double check. "
            fi
        )&
    done
done

wait


#####################################################################
# merging results
#####################################################################
docker run --rm -v `pwd`:`pwd` -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /postprocessing/postprocessing_combine_turtle_from_all_sources.py \
    --root_folder ${data_root_result} \
    --final_dir_name 'final' \
    --output_folder ${output_ttl}
echo "Final output of English, Russian, Ukrainian in "${output_ttl}


#####################################################################
# docker stop
#####################################################################
#docker stop $(docker ps -q --filter ancestor=<image-name> )
#docker stop $(docker container ls -q --filter name=db*)
echo "Stop dockers..."
docker stop db
docker stop nominal_coreference
docker stop aida_entity
docker stop event_coreference_en
docker stop event_coreference_ru
docker stop event_coreference_uk
docker ps

exit 0