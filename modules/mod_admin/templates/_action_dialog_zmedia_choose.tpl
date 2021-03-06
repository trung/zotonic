{% tabs id=#tabs %}
<div id="{{ #tabs }}">
	<ul class="clearfix">
		<li><a href="#{{ #tab }}-media">Media on this page</a></li>
		<li><a href="#{{ #tab }}-search">Search other media</a></li>
	</ul>

	<div id="{{ #tab }}-media">
		<p>Choose a media item from this page to insert in the body text.</p>

		{% with m.rsc[id].o.depiction as ids %}
		{% include "_choose_media.tpl" %}
		{% endwith %}

        <div class="form-item clearfix">
        {% button
                text="add a new media item" 
                action={dialog_media_upload subject_id=id group_id=r.group_id stay
                        action={postback 
                                postback={zmedia_choose} 
                                          delegate="action_admin_zmedia_choose"}
						action={postback
								postback={reload_media rsc_id=id div_id=media_div_id}
 										  delegate="resource_admin_edit"}
                        }
        %}
        </div>

    </div>

	<div id="{{ #tab }}-search">
		<div class="form-item clearfix">


            <p>Use the autocompleter to search the media in this site.</p>

            <div class="form-item autocomplete-wrapper clear">
                <input id="{{#input}}" class="autocompleter" type="text" value="" />
                <ul id="{{#suggestions}}" class="suggestions-list"></ul>
            </div>

            {% wire id=#input
            type="keyup" 
            action={typeselect
            target=#suggestions 
            action_with_id={with_args action={link subject_id=subject_id predicate="depiction" element_id=element_id} arg={object_id select_id}
            }
			action={postback postback={reload_media rsc_id=id div_id=media_div_id} delegate="resource_admin_edit"}
            action_with_id={with_args action={zmedia_has_chosen} arg={id select_id}}
            action={dialog_close}

            cat=m.predicate.object_category[predicate]
			}
            %}

		</div>	
    </div>
