#!/usr/bin/env bash

######################################################
# Arguments
######################################################
data_root=$1
parent_child_tab_path=$2
lang=$3
source=$4
use_nominal_corefer=1

# ltf source folder path
ltf_source=${data_root}/ltf
# rsd source folder path
rsd_source=${data_root}/rsd
# file list of ltf files (only file names)
ltf_file_list=${data_root}/ltf_lst
#ls ${ltf_source} > ${ltf_file_list}
# file list of rsd files (absolute paths, this is a temporary file)
rsd_file_list=${data_root}/rsd_lst
#readlink -f ${rsd_source}/* > ${rsd_file_list}

# edl output
edl_output_dir=${data_root}/mention
edl_bio=${data_root}/edl/${lang}.bio
edl_cfet_json=${edl_output_dir}/english.nam.cfet.json
edl_tab_nam_bio=${edl_output_dir}/english.nam.bio
edl_tab_nam_filename=english.nam.tab
edl_tab_nom_filename=english.nom.tab
edl_tab_pro_filename=english.pro.tab
edl_vec_file=english.mention.hidden.txt
evt_vec_file=english.trigger.hidden.txt
edl_tab_nam=${edl_output_dir}/${edl_tab_nam_filename}
edl_tab_nom=${edl_output_dir}/${edl_tab_nom_filename}
edl_tab_pro=${edl_output_dir}/${edl_tab_pro_filename}
edl_tab_link=${edl_output_dir}/${lang}.linking.tab
edl_tab_link_fb=${edl_output_dir}/${lang}.linking.freebase.tab
edl_tab_coref_ru=${edl_output_dir}/${lang}.coreference.tab
geonames_features=${edl_output_dir}/${lang}.linking.geo.json
edl_tab_final=${edl_output_dir}/merged_final.tab
edl_cs_coarse=${edl_output_dir}/merged.cs
entity_fine_model=${edl_output_dir}/merged_fine.tsv
edl_cs_fine=${edl_output_dir}/merged_fine.cs
edl_json_fine=${edl_output_dir}/${lang}.linking.freebase.fine.json
edl_tab_freebase=${edl_output_dir}/${lang}.linking.freebase.tab
freebase_private_data=${edl_output_dir}/freebase_private_data.json
lorelei_link_private_data=${edl_output_dir}/lorelei_private_data.json
entity_lorelei_multiple=${edl_output_dir}/${lang}.linking.tab.candidates.json
edl_cs_fine_all=${edl_output_dir}/merged_all_fine.cs
edl_cs_fine_protester=${edl_output_dir}/merged_all_fine_protester.cs
edl_cs_info=${edl_output_dir}/merged_all_fine_info.cs
edl_cs_info_conf=${edl_output_dir}/merged_all_fine_info_conf.cs
edl_cs_color=${edl_output_dir}/${lang}.linking.col.tab
conf_all=${edl_output_dir}/all_conf.txt
ground_truth_tab_dir=${edl_output_dir}/ldc_anno_matched

# filler output
core_nlp_output_path=${data_root}/corenlp
filler_coarse=${edl_output_dir}/filler_${lang}.cs
filler_fine=${edl_output_dir}/filler_fine.cs
udp_dir=${data_root}/udp
chunk_file=${data_root}/edl/chunk.txt

# relation output
relation_result_dir=${data_root}/relation   # final cs output file path
relation_cs_coarse=${relation_result_dir}/${lang}.rel.cs # final cs output for relation
relation_cs_fine=${relation_result_dir}/${lang}/${lang}.fine_rel.cs # final cs output for relation
new_relation_coarse=${relation_result_dir}/new_relation_${lang}.cs

# event output
event_result_dir=${data_root}/cs
event_coarse_without_time=${event_result_dir}/event.cs
event_coarse_with_time=${event_result_dir}/events_tme.cs
event_fine=${event_result_dir}/events_fine.cs
event_frame=${event_result_dir}/events_fine_framenet.cs
event_depen=${event_result_dir}/events_fine_depen.cs
event_fine_all=${event_result_dir}/events_fine_all.cs
event_fine_all_clean=${event_result_dir}/events_fine_all_clean.cs
event_corefer=${event_result_dir}/events_corefer.cs
event_corefer_time=${event_result_dir}/events_corefer_timefix.cs
event_final=${event_result_dir}/events_info.cs
ltf_txt_path=${event_result_dir}/'ltf_txt'
framenet_path=${data_root}/event/'framenet_res'

# final output
merged_cs=${data_root}/${lang}${source}_full.cs
merged_cs_link=${data_root}/${lang}${source}_full_link.cs
ttl_initial=${data_root}/initial
ttl_initial_private=${data_root}/initial_private_data
ttl_final=${data_root}/final

######################################################
# Running scripts
######################################################

# EDL
# entity extraction
echo "** Extracting coarse-grained entities, relations, and events **"
docker run --rm -i -v `pwd`:/data -w /oneie limteng/oneie_aida \
    /opt/conda/bin/python \
    /oneie/predict.py ${ltf_source} ${data_root} english 20 100 5 1
# fine-grained typing by model
echo "fine-grained typing started"
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i --network="host" limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /entity/aida_edl/typing.py \
    ${lang} ${edl_tab_nam_bio} ${entity_fine_model}
echo "fine-grained typing finished"

## linking
echo "** Linking entities to KB **"
docker run -v ${PWD}/system/aida_edl/edl_data:/data \
    -v ${edl_output_dir}:/testdata_${lang}${source} \
    --link db:mongo panx27/edl \
    python ./projs/docker_aida19/aida19.py \
    ${lang} \
    /testdata_${lang}${source}/${edl_tab_nam_filename} \
    /testdata_${lang}${source}/${edl_tab_nom_filename} \
    /testdata_${lang}${source}/${edl_tab_pro_filename} \
    /testdata_${lang}${source}
## nominal coreference
echo "** Starting nominal coreference **"
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i --network="host" limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /entity/aida_edl/nominal_corefer_en.py \
    --dev ${edl_bio} \
    --dev_e ${edl_tab_link} \
    --dev_f ${edl_tab_link_fb} \
    --out_e ${edl_tab_final} \
    --use_nominal_corefer ${use_nominal_corefer}
## tab2cs
docker run --rm -v ${data_root}:${data_root} -w `pwd`  -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /entity/aida_edl/tab2cs.py \
    ${edl_tab_final} ${edl_cs_coarse} 'EDL'


# Relation Extraction (coarse-grained)
echo "** Extraction relations **"
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/aida_relation_coarse/bin/python \
    -u /relation/CoarseRelationExtraction/exec_relation_extraction.py \
    -i ${lang} \
    -l ${ltf_file_list} \
    -f ${ltf_source} \
    -e ${edl_cs_coarse} \
    -t ${edl_tab_final} \
    -o ${relation_cs_coarse}
# # Filler Extraction & new relation
docker run --rm -v ${data_root}:${data_root} -w /scr -i dylandilu/filler \
    python extract_filler_relation.py \
    --corenlp_dir ${core_nlp_output_path} \
    --ltf_dir ${ltf_source} \
    --edl_path ${edl_cs_coarse} \
    --text_dir ${rsd_source} \
    --path_relation ${new_relation_coarse} \
    --path_filler ${filler_coarse} \
    --lang ${lang}

## Fine-grained Entity
echo "** Fine-grained entity typing **"
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i --network="host" limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /entity/aida_edl/fine_grained_entity.py \
    ${lang} ${edl_json_fine} ${edl_tab_freebase} ${entity_fine_model} \
    ${geonames_features} ${edl_cs_coarse} ${edl_cs_fine} ${filler_fine} \
    --filler_coarse ${filler_coarse} \
    --ground_truth_tab_dir ${ground_truth_tab_dir} \
    --ltf_dir ${ltf_source} --rsd_dir ${rsd_source}
## Add time argument
docker run -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /event/aida_event/postprocessing_add_time_expression.py \
    ${ltf_source} ${filler_coarse} ${event_coarse_without_time} ${event_coarse_with_time}

# Relation Extraction (fine)
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    -u /relation/FineRelationExtraction/EVALfine_grained_relations.py \
    --lang_id ${lang} \
    --ltf_dir ${ltf_source} \
    --rsd_dir ${rsd_source} \
    --cs_fnames ${edl_cs_coarse} ${filler_coarse} ${relation_cs_coarse} ${new_relation_coarse} ${event_coarse_with_time} \
    --fine_ent_type_tab ${edl_tab_freebase} \
    --fine_ent_type_json ${edl_json_fine} \
    --outdir ${relation_result_dir} \
    --fine_grained
##   --reuse_cache \
##   --use_gpu \
## Postprocessing, adding informative justification
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /aida_utilities/pipeline_merge_m18.py \
    --cs_fnames ${edl_cs_fine} ${filler_fine} \
    --output_file ${edl_cs_fine_all}



echo "add protester"
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i --network="host" limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /entity/aida_edl/add_protester.py \
    ${event_coarse_with_time} ${edl_cs_fine_all} ${edl_cs_fine_protester}
echo "** Informative Justification **"
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /entity/aida_edl/entity_informative.py ${chunk_file} ${edl_cs_fine_protester} ${edl_cs_info}
## update mention confidence
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /aida_utilities/rewrite_mention_confidence.py \
    ${lang}${source} ${edl_tab_nam} ${edl_tab_nom} ${edl_tab_pro} \
    ${edl_tab_link} ${entity_lorelei_multiple} ${ltf_source} \
    ${edl_cs_info} ${edl_cs_info_conf} ${conf_all}
# Event (Fine-grained)
echo "** Event fine-grained typing **"
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /event/aida_event/fine_grained/fine_grained_events.py \
    ${lang} ${ltf_source} ${edl_json_fine} ${edl_tab_freebase} \
    ${edl_cs_coarse} ${event_coarse_with_time} ${event_fine} \
    --filler_coarse ${filler_coarse} \
    --entity_finegrain_aida ${edl_cs_fine_all}
## Event Rule-based
echo "** Event rule-based **"
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /event/aida_event/framenet/new_event_framenet.py \
    ${framenet_path} ${ltf_source} ${rsd_source} \
    ${edl_cs_coarse} ${filler_coarse} ${event_fine} ${event_frame}
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /event/aida_event/framenet/new_event_dependency.py \
    ${rsd_source} ${core_nlp_output_path} \
    ${edl_cs_coarse} ${filler_coarse} ${event_fine} ${event_frame} ${event_depen}
## Combine fine-grained typing and rule-based
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /aida_utilities/pipeline_merge_m18.py \
    --cs_fnames ${event_fine} ${event_frame} ${event_depen} \
    --output_file ${event_fine_all}
## rewrite-args
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /event/aida_event/fine_grained/rewrite_args.py \
    ${event_fine_all} ${ltf_source} ${event_fine_all_clean}_tmp ${lang}
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /event/aida_event/fine_grained/rewrite_args.py \
    ${event_fine_all_clean}_tmp ${ltf_source} ${event_fine_all_clean} ${lang}
echo "Fix time and format"
## Event coreference
echo "** Event coreference **"
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i --network="host" limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /event/aida_event_coreference/gail_event_coreference_test_${lang}.py \
    -i ${event_fine_all_clean} -o ${event_corefer} -r ${rsd_source}
### update `time` format
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /event/aida_event/fine_grained/rewrite_time.py \
    ${event_corefer} ${event_corefer_time}
### updating informative mention
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /event/aida_event/postprocessing_event_informative_mentions.py \
    ${ltf_source} ${event_corefer_time} ${event_final}
echo "Update event informative mention"

# Final Merge
echo "** Merging all items **"
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /aida_utilities/pipeline_merge_m18.py \
    --cs_fnames ${edl_cs_info_conf} ${edl_cs_color} ${relation_cs_fine} ${event_final} \
    --output_file ${merged_cs}
# multiple freebase links
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /aida_utilities/postprocessing_link_freebase.py \
    ${edl_tab_freebase} ${merged_cs} ${freebase_private_data}
# multiple lorelei links
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /aida_utilities/postprocessing_link_confidence.py \
    ${entity_lorelei_multiple} ${merged_cs} ${merged_cs_link} ${lorelei_link_private_data}


######################################################
# Format converter
######################################################
# AIF converter
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /postprocessing/postprocessing_converter_params.py \
    ${data_root}/converter.param ${merged_cs_link} ${ttl_initial}
docker run --rm -v ${data_root}:/aida-tools-master/sample_params/m18-eval/${data_root} -w /aida-tools-master -i limanling/aida-tools \
    /aida-tools-master/aida-eval-tools/target/appassembler/bin/coldstart2AidaInterchange  \
    sample_params/m18-eval/${data_root}/converter.param
# Append private information
docker run --rm -v ${data_root}:${data_root} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /postprocessing/postprocessing_append_private_data.py \
    --language_id ${lang}${source} \
    --initial_folder ${ttl_initial} \
    --output_folder ${ttl_initial_private} \
    --fine_grained_entity_type_path ${edl_json_fine} \
    --freebase_link_mapping ${freebase_private_data} \
    --lorelei_link_mapping ${lorelei_link_private_data} \
    --ent_vec_dir ${edl_output_dir} \
    --ent_vec_files ${edl_vec_file}
docker run --rm -v ${data_root}:${data_root} -v ${parent_child_tab_path}:${parent_child_tab_path} -w `pwd` -i limanling/uiuc_ie_m18 \
    /opt/conda/envs/py36/bin/python \
    /postprocessing/postprocessing_rename_turtle.py \
    --language_id ${lang}${source} \
    --input_private_folder ${ttl_initial_private} \
    --output_folder ${ttl_final} \
    --parent_child_tab_path ${parent_child_tab_path} \
    --child_column_idx 2 \
    --parent_column_idx 7

echo "Final result in Cold Start Format is in "${merged_cs_link}
echo "Final result in RDF Format is in "${ttl_final}
