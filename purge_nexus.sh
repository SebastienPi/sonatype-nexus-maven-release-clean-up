#!/bin/sh
# Purge Nexus
# Copyright (C) 2024 Sébastien Picavet
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 2 of the License.
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Règles :
# * exclure des « groupes » ou des composants ;
# * garder les X dernières sorties pour chaque couple (groupe/composant).

declare -r AUTHENTIFICATION=''
declare -r BASE_URL='http://127.0.0.1:8080'
declare -r COMPOSANTS_EXCLUS=''
declare -r GROUPES_EXCLUS=''
declare -r GARDER_X_VERSIONS=3


while getopts 'sv' OPTION
do
	case "${OPTION}" in
		s)
			declare -r CURL_OPTS='--silent --show-error'
			declare -r SIMULATION=true;;
		v)
			declare -r CURL_OPTS='--verbose'
			declare -r VERBEUX=true;;
		?)
			echo "Usage : $(basename "${0}") [-s] [-v]"
			echo "	-s : mode simulation"
			echo "	-v : sortie verbeuse"
			exit 1
	esac
done


[ "${VERBEUX}" ] && echo "Options : SIMULATION=${SIMULATION} et VERBEUX=${VERBEUX}"


[ "${VERBEUX}" ] && echo 'Appel Nexus'
reponses=$(curl ${CURL_OPTS} --user "${AUTHENTIFICATION}" "${BASE_URL}/service/rest/v1/components?repository=releases")
jetonSuivant=$(echo "${reponses}" | jq --raw-output '.continuationToken // empty')
[ "${VERBEUX}" ] && echo "Jeton suivant : ${jetonSuivant}"


# Bouclement, il faut tout lire car l’ordre n’est pas garanti
while [ "${jetonSuivant}" != "" ]
do
	[ "${VERBEUX}" ] && echo 'Nouvelle itération'

	reponse=$(curl ${CURL_OPTS} --user "${AUTHENTIFICATION}" "${BASE_URL}/service/rest/v1/components?repository=releases&continuationToken=${jetonSuivant}")
	jetonSuivant=$(echo "${reponse}" | jq --raw-output '.continuationToken // empty')

	# Concaténer avec tout
	reponses="${reponses}${reponse}"

	[ "${VERBEUX}" ] && echo "Jeton suivant ? ${jetonSuivant}"
done


# Groupements
# Explications : extraction des informations dont nous avons besoin ; regroupement par groupe et composant ; bidouillage pour avoir une ligne par couple afin de compter et sheller un peu
for i in $(echo "${reponses}" | jq '.items[] | {groupe: .group, composant: .name, version: .version}' | jq --slurp --compact-output 'group_by(.groupe, .composant)' | sed 's/\],\[/\]\n\[/g' | sed 's/\[\[/\[/' | sed 's/\]\]/\]/')
do
	# Plus de X versions ?
	if [ $(echo "${i}" | jq 'length') -gt ${GARDER_X_VERSIONS} ]
	then
		[ "${VERBEUX}" ] && echo "\nPlus de trois versions : $(echo ${i} | jq)"

		# Groupe exclu ?
		groupe=$(echo "${i}" | jq --raw-output '.[0].groupe')
		echo "${groupe}" | egrep --word-regexp "${GROUPES_EXCLUS}" > /dev/null
		if [ $? -ne 0 ]
		then

			# Composant exclu ?
			composant=$(echo "${i}" | jq --raw-output '.[0].composant')
			echo "${i}" | jq --raw-output '.[0].groupe +"."+ .[0].composant' | egrep --word-regexp "${COMPOSANTS_EXCLUS}" > /dev/null
			if [ $? -ne 0 ]
			then

				# Trier les versions et exclure les 3 dernières lignes
				for j in $(echo "${i}" | jq --raw-output '.[].version' | sort --version-sort | head --lines -3)
				do
					echo "Suppression de la version ${j} du composant ${groupe}.${composant}"
					[ "${VERBEUX}" ] && echo "\nSuppression des fichiers : $(echo "${reponses}" | jq --raw-output '.items[] | select(.group == "'${groupe}'" and .name == "'${composant}'" and .version == "'${j}'") | .assets[].path')"

					for k in $(echo "${reponses}" | jq --raw-output '.items[] | select(.group == "'${groupe}'" and .name == "'${composant}'" and .version == "'${j}'") | .assets[].id')
					do
						if [ ${SIMULATION} ]
						then
							echo "curl ${CURL_OPTS} --request DELETE -v --user ${AUTHENTIFICATION}" "${BASE_URL}/service/rest/v1/assets/${k}"
						else
							curl ${CURL_OPTS} --request DELETE -v --user "${AUTHENTIFICATION}" "${BASE_URL}/service/rest/v1/assets/${k}"
						fi
					done
				done
			else
				echo "Composant « ${composant} » exclu, passage à l’itération suivante."
			fi
		else
			echo "Groupe « ${groupe} » exclu, passage à l’itération suivante."
		fi
	fi
done