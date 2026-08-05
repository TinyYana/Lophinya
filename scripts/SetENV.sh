prop() {
  grep "^[[:space:]]*${1}" gradle.properties | cut -d'=' -f2 | sed 's/^[[:space:]]*//; s/\r//'
}

# The Gradle modules and upstream branding still use "lophine" internally.
# Public release artifacts belong to this fork and should be named Lophinya.
project_id="lophinya"
project_id_b="Lophinya"
build_output_prefix="lophine"

commitid=$(git log --pretty='%h' -1)
mcversion=$(prop mcVersion)
release=$(prop release)
pushRepo=$(prop pushRepo)
release_tag="$mcversion-nya-$commitid"
jarName="$project_id-paperclip-$mcversion-$commitid.jar"
jarName_dir="lophine-server/build/libs/$jarName"

flag_push_repo=false
flag_release=false
pre=false

if [ "$release" = "pre" ]; then
  pre=true
  flag_release=true
  make_latest=true
  flag_push_repo=true
elif [ "$release" = "true" ]; then
  flag_release=true
  make_latest=true
  flag_push_repo=true
fi

if [ "$pushRepo" = "true" ]; then
  flag_push_repo=true
elif [ "$pushRepo" = "false" ]; then
  flag_push_repo=false
fi

actual_jar=$(find lophine-server/build/libs -maxdepth 1 -type f -name "$build_output_prefix-paperclip-*.jar" -print | sort | head -n 1)
if [ -z "$actual_jar" ]; then
  echo "::error::No Lophine paperclip build output was found to publish as Lophinya" >&2
  exit 1
fi

if [ "$actual_jar" != "$jarName_dir" ]; then
  mv "$actual_jar" "$jarName_dir"
fi

echo "project_id=$project_id" >> "$GITHUB_ENV"
echo "project_id_b=$project_id_b" >> "$GITHUB_ENV"
echo "commit_id=$commitid" >> "$GITHUB_ENV"
echo "commit_msg=$(git log --pretty='> [%h] %s' -1)" >> "$GITHUB_ENV"
echo "mcversion=$mcversion" >> "$GITHUB_ENV"
echo "pre=$pre" >> "$GITHUB_ENV"
echo "tag=$release_tag" >> "$GITHUB_ENV"
echo "jar=$jarName" >> "$GITHUB_ENV"
echo "jar_dir=$jarName_dir" >> "$GITHUB_ENV"
echo "flag_push_repo=$flag_push_repo" >> "$GITHUB_ENV"
echo "flag_release=$flag_release" >> "$GITHUB_ENV"
echo "make_latest=$make_latest" >> "$GITHUB_ENV"
