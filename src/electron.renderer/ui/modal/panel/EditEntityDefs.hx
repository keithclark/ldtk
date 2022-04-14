package ui.modal.panel;

import data.DataTypes;

class EditEntityDefs extends ui.modal.Panel {
	static var LAST_ENTITY_ID = -1;

	var jEntityList(get,never) : js.jquery.JQuery; inline function get_jEntityList() return jContent.find(".entityList>ul");
	var jEntityForm(get,never) : js.jquery.JQuery; inline function get_jEntityForm() return jContent.find(".entityForm>dl.form");
	var jPreview(get,never) : js.jquery.JQuery; inline function get_jPreview() return jContent.find(".previewWrapper");

	var curEntity : Null<data.def.EntityDef>;
	var fieldsForm : FieldDefsForm;


	public function new(?editDef:data.def.EntityDef) {
		super();

		loadTemplate( "editEntityDefs", "defEditor entityDefs" );
		linkToButton("button.editEntities");

		function _createEntity() {
			var ed = project.defs.createEntityDef();
			selectEntity(ed);
			editor.ge.emit(EntityDefAdded);
			jEntityForm.find("input").first().focus().select();
			return ed;
		}

		// Create entity
		jEntityList.parent().find("button.create").click( _->_createEntity() );

		// Presets
		jEntityList.parent().find("button.presets").click( (ev)->{
			var ctx = new ContextMenu(ev);
			ctx.add({
				label: L.t._("Rectangle region"),
				cb: ()->{
					var ed = _createEntity();
					ed.identifier = project.fixUniqueIdStr("RectRegion", (s)->project.defs.isEntityIdentifierUnique(s));
					ed.hollow = true;
					ed.resizableX = true;
					ed.resizableY = true;
					ed.pivotX = ed.pivotY = 0;
					ed.tags.set("region");
					selectEntity(ed);
					editor.ge.emit( EntityDefChanged );
				}
			});
			ctx.add({
				label: L.t._("Circle region"),
				cb: ()->{
					var ed = _createEntity();
					ed.identifier = project.fixUniqueIdStr("CircleRegion", (s)->project.defs.isEntityIdentifierUnique(s));
					ed.renderMode = Ellipse;
					ed.hollow = true;
					ed.resizableX = true;
					ed.resizableY = true;
					ed.keepAspectRatio = true;
					ed.pivotX = ed.pivotY = 0.5;
					ed.tags.set("region");
					selectEntity(ed);
					editor.ge.emit( EntityDefChanged );
				}
			});
		});

		// Create fields editor
		fieldsForm = new ui.FieldDefsForm( FP_Entity );
		jContent.find("#fields").replaceWith( fieldsForm.jWrapper );


		// Select same entity as current client selection
		if( editDef!=null )
			selectEntity( editDef );
		else if( editor.curLayerDef!=null && editor.curLayerDef.type==Entities )
			selectEntity( project.defs.getEntityDef(editor.curTool.getSelectedValue()) );
		else if( LAST_ENTITY_ID>=0 && project.defs.getEntityDef(LAST_ENTITY_ID)!=null )
			selectEntity( project.defs.getEntityDef(LAST_ENTITY_ID) );
		else
			selectEntity(project.defs.entities[0]);

		checkHelpBanner( ()->project.defs.entities.length<=3 );
	}


	function deleteEntityDef(ed:data.def.EntityDef, bypassConfirm=false) {
		var isUsed = project.isEntityDefUsed(ed);
		if( isUsed && !bypassConfirm) {
			new ui.modal.dialog.Confirm(
				Lang.t._("WARNING! This entity is used in one or more levels. The corresponding instances will also be deleted!"),
				true,
				deleteEntityDef.bind(ed,true)
			);
			return;
		}
			// : Lang.t._("This entity is not used and can be safely removed."),

		new ui.LastChance( L.t._("Entity ::name:: deleted", { name:ed.identifier }), project );
		project.defs.removeEntityDef(ed);
		editor.ge.emit(EntityDefRemoved);
		if( project.defs.entities.length>0 )
			selectEntity(project.defs.entities[0]);
		else
			selectEntity(null);
	}

	override function onGlobalEvent(e:GlobalEvent) {
		super.onGlobalEvent(e);
		switch e {
			case ProjectSettingsChanged, LevelSettingsChanged(_), LevelSelected(_):
				close();

			case ProjectSelected:
				updatePreview();
				updateEntityForm();
				updateFieldsForm();
				updateEntityList();
				selectEntity(project.defs.entities[0]);

			case LayerInstancesRestoredFromHistory(_):
				updatePreview();
				updateEntityForm();
				updateFieldsForm();
				updateEntityList();

			case EntityDefChanged, EntityDefAdded, EntityDefRemoved:
				updatePreview();
				updateEntityForm();
				updateFieldsForm();
				updateEntityList();

			case EntityDefSorted, FieldDefSorted:
				updateEntityList();

			case FieldDefAdded(_), FieldDefRemoved(_), FieldDefChanged(_):
				updateEntityList();
				updateFieldsForm();

			case ExternalEnumsLoaded(anyCriticalChange):
				updateEntityList();
				updateFieldsForm();

			case _:
		}
	}

	function selectEntity(ed:Null<data.def.EntityDef>) {
		if( ed==null )
			ed = editor.project.defs.entities[0];

		curEntity = ed;
		LAST_ENTITY_ID = curEntity==null ? -1 : curEntity.uid;
		updatePreview();
		updateEntityForm();
		updateFieldsForm();
		updateEntityList();
	}

	function updateEntityForm() {
		ui.Tip.clear();
		jEntityForm.find("*").off(); // cleanup event listeners

		var jAll = jEntityForm.add( jPreview );
		if( curEntity==null ) {
			jAll.css("visibility","hidden");
			jContent.find(".none").show();
			return;
		}

		JsTools.parseComponents(jEntityForm);
		jAll.css("visibility","visible");
		jContent.find(".none").hide();


		// Name
		var i = Input.linkToHtmlInput(curEntity.identifier, jEntityForm.find("input[name='name']") );
		i.fixValue = (v)->project.fixUniqueIdStr(v, (id)->project.defs.isEntityIdentifierUnique(id, curEntity));
		i.linkEvent(EntityDefChanged);

		// Hollow (ie. click through)
		var i = Input.linkToHtmlInput(curEntity.hollow, jEntityForm.find("input[name=hollow]") );
		i.linkEvent(EntityDefChanged);

		// Tags editor
		var ted = new ui.TagEditor(
			curEntity.tags,
			()->editor.ge.emit(EntityDefChanged),
			()->project.defs.getRecallEntityTags([curEntity.tags])
		);
		jEntityForm.find("#tags").empty().append(ted.jEditor);

		// Dimensions
		var i = Input.linkToHtmlInput( curEntity.width, jEntityForm.find("input[name='width']") );
		i.setBounds(1,2048);
		i.onChange = editor.ge.emit.bind(EntityDefChanged);

		// Resizable
		var i = Input.linkToHtmlInput( curEntity.resizableX, jEntityForm.find("input#resizableX") );
		i.onChange = editor.ge.emit.bind(EntityDefChanged);
		var i = Input.linkToHtmlInput( curEntity.resizableY, jEntityForm.find("input#resizableY") );
		i.onChange = editor.ge.emit.bind(EntityDefChanged);
		var i = Input.linkToHtmlInput( curEntity.keepAspectRatio, jEntityForm.find("input#keepAspectRatio") );
		i.onChange = editor.ge.emit.bind(EntityDefChanged);
		i.setEnabled( curEntity.resizableX && curEntity.resizableY );

		var i = Input.linkToHtmlInput( curEntity.height, jEntityForm.find("input[name='height']") );
		i.setBounds(1,2048);
		i.onChange = editor.ge.emit.bind(EntityDefChanged);

		// Display renderMode form fields based on current mode
		var jRenderModeBlock = jEntityForm.find("dd.renderMode");
		JsTools.removeClassReg(jRenderModeBlock, ~/mode_\S+/g);
		jRenderModeBlock.addClass("mode_"+curEntity.renderMode);
		jRenderModeBlock.find(".tilePicker").empty();

		// Color
		var col = jEntityForm.find("input[name=color]");
		col.val( C.intToHex(curEntity.color) );
		col.change( function(ev) {
			curEntity.color = C.hexToInt( col.val() );
			editor.ge.emit(EntityDefChanged);
			updateEntityForm();
		});

		// Fill/line opacities
		var i = Input.linkToHtmlInput(curEntity.tileOpacity, jEntityForm.find("#tileOpacity"));
		i.setBounds(0, 1);
		i.enablePercentageMode();
		i.linkEvent( EntityDefChanged );
		i.setEnabled(curEntity.renderMode==Tile);

		var i = Input.linkToHtmlInput(curEntity.fillOpacity, jEntityForm.find("#fillOpacity"));
		i.setBounds(0, 1);
		i.enablePercentageMode();
		i.setEnabled(!curEntity.hollow);
		i.linkEvent( EntityDefChanged );

		var i = Input.linkToHtmlInput(curEntity.lineOpacity, jEntityForm.find("#lineOpacity"));
		i.setBounds(0, 1);
		i.enablePercentageMode();
		i.linkEvent( EntityDefChanged );

		// Entity render mode
		var jRenderSelect = jRenderModeBlock.find(".renderMode");
		jRenderSelect.empty();
		var jOptGroup = new J('<optgroup label="Shapes"/>');
		jOptGroup.appendTo(jRenderSelect);
		for(k in ldtk.Json.EntityRenderMode.getConstructors()) {
			var mode = ldtk.Json.EntityRenderMode.createByName(k);
			if( mode==Tile )
				continue;

			var jOpt = new J('<option value="!$k"/>');
			jOpt.appendTo(jOptGroup);
			jOpt.text(switch mode {
				case Rectangle: Lang.t._("Rectangle");
				case Ellipse: Lang.t._("Ellipse");
				case Cross: Lang.t._("Cross");
				case Tile: null;
			});
		}
		JsTools.appendTilesetsToSelect(project, jRenderSelect);

		// Pick render mode
		jRenderSelect.change( function(ev) {
			var oldMode = curEntity.renderMode;
			curEntity._oldTileId = null;
			curEntity.tileRect = null; // NOTE: important to clear as tilesetUid is also stored in it!

			var raw : String = jRenderSelect.val();
			if( M.isValidNumber(Std.parseInt(raw)) ) {
				// Tileset UID
				curEntity.renderMode = Tile;
				curEntity.tilesetId = Std.parseInt(raw);
		}
			else {
				if( raw.indexOf("!")==0 ) {
					// Shape
					curEntity.renderMode = ldtk.Json.EntityRenderMode.createByName( raw.substr(1) );
					curEntity.tilesetId = null;
				}
				else {
					// Embed tileset
					var embedId = ldtk.Json.EmbedAtlas.createByName(raw);
					var td = project.defs.getEmbedTileset(embedId);
					curEntity.renderMode = Tile;
					curEntity.tilesetId = td.uid;
				}
			}

			// Re-init opacities
			if( oldMode!=Tile && curEntity.renderMode==Tile ) {
				curEntity.tileOpacity = 1;
				curEntity.fillOpacity = 0.08;
				curEntity.lineOpacity = 0;
			}
			if( oldMode==Tile && curEntity.renderMode!=Tile ) {
				curEntity.tileOpacity = 1;
				curEntity.fillOpacity = 1;
				curEntity.lineOpacity = 1;
			}

			editor.ge.emit( EntityDefChanged );
		});

		if( curEntity.tilesetId!=null ) {
			var td = project.defs.getTilesetDef(curEntity.tilesetId);
			if( td.isUsingEmbedAtlas() )
				jRenderSelect.val( td.embedAtlas.getName() );
			else
				jRenderSelect.val( Std.string(td.uid) );
		}
		else
			jRenderSelect.val( "!"+curEntity.renderMode.getName() );


		// Tile render mode
		var i = new form.input.EnumSelect(
			jEntityForm.find("select.tileRenderMode"),
			ldtk.Json.EntityTileRenderMode,
			()->curEntity.tileRenderMode,
			(v)->curEntity.tileRenderMode = v,
			(v)->switch v {
				case Cover: L.t._("Cover bounds");
				case FitInside: L.t._("Fit inside bounds");
				case Repeat: L.t._("Repeat");
				case Stretch: L.t._("Dirty stretch to bounds");
				case FullSizeCropped: L.t._("Full size (cropped in bounds)");
				case FullSizeUncropped: L.t._("Full size (not cropped)");
				case NineSlice: L.t._("9-slices scaling");
			}
		);
		i.linkEvent( EntityDefChanged );

		if( curEntity.tileRenderMode!=NineSlice )
			jEntityForm.find(".nineSlice").hide();
		else {
			jEntityForm.find(".nineSlice").show();
			if( curEntity.nineSliceBorders.length!=4 )
				curEntity.nineSliceBorders = [2,2,2,2];

			var i = Input.linkToHtmlInput(curEntity.nineSliceBorders[0], jEntityForm.find("[name=nineSliceUp]"));
			i.linkEvent(EntityDefChanged);
			i.setBounds(1, null);
			var i = Input.linkToHtmlInput(curEntity.nineSliceBorders[1], jEntityForm.find("[name=nineSliceRight]"));
			i.linkEvent(EntityDefChanged);
			i.setBounds(1, null);
			var i = Input.linkToHtmlInput(curEntity.nineSliceBorders[2], jEntityForm.find("[name=nineSliceDown]"));
			i.linkEvent(EntityDefChanged);
			i.setBounds(1, null);
			var i = Input.linkToHtmlInput(curEntity.nineSliceBorders[3], jEntityForm.find("[name=nineSliceLeft]"));
			i.linkEvent(EntityDefChanged);
			i.setBounds(1, null);
		}

		// Tile rect picker
		if( curEntity.renderMode==Tile ) {
			var jPicker = JsTools.createTileRectPicker(
				curEntity.tilesetId,
				curEntity.tileRect,
				(rect)->{
					if( rect!=null ) {
						curEntity.tileRect = rect;
						editor.ge.emit(EntityDefChanged);
					}
				}
			);
			jPicker.appendTo( jRenderModeBlock.find(".tilePicker") );
		}


		// Max count
		var i = Input.linkToHtmlInput(curEntity.maxCount, jEntityForm.find("input#maxCount") );
		i.setBounds(0,1024);
		i.onChange = editor.ge.emit.bind(EntityDefChanged);
		if( curEntity.maxCount==0 )
			i.jInput.val("");

		var i = new form.input.EnumSelect(
			i.jInput.siblings("[name=scope]"),
			ldtk.Json.EntityLimitScope,
			()->curEntity.limitScope,
			(e)->curEntity.limitScope = e,
			(e)->switch e {
				case PerLayer: L.t._("per layer");
				case PerLevel: L.t._("per level");
				case PerWorld: L.t._("in the world");
			}
		);
		i.setEnabled(curEntity.maxCount>0);

		// Behavior when max is reached
		var i = new form.input.EnumSelect(
			jEntityForm.find("select[name=limitBehavior]"),
			ldtk.Json.EntityLimitBehavior,
			function() return curEntity.limitBehavior,
			function(v) {
				curEntity.limitBehavior = v;
			},
			function(k) {
				return switch k {
					case DiscardOldOnes: Lang.t._("discard older ones");
					case PreventAdding: Lang.t._("prevent adding more");
					case MoveLastOne: Lang.t._("move the last one instead of adding");
				}
			}
		);
		i.setEnabled( curEntity.maxCount>0 );

		// Show name
		var i = Input.linkToHtmlInput(curEntity.showName, jEntityForm.find("#showIdentifier"));
		i.linkEvent(EntityDefChanged);

		// Pivot
		var jPivots = jEntityForm.find(".pivot");
		jPivots.empty();
		var p = JsTools.createPivotEditor(curEntity.pivotX, curEntity.pivotY, curEntity.color, function(x,y) {
			curEntity.pivotX = x;
			curEntity.pivotY = y;
			editor.ge.emit(EntityDefChanged);
		});
		jPivots.append(p);

		checkBackup();
	}


	function updateFieldsForm() {
		if( curEntity!=null )
			fieldsForm.useFields(curEntity.identifier, curEntity.fieldDefs);
		else {
			fieldsForm.useFields("Entity", []);
			fieldsForm.hide();
		}
		checkBackup();
	}


	function updateEntityList() {
		jEntityList.empty();

		// List context menu
		ContextMenu.addTo(jEntityList, false, [
			{
				label: L._Paste(),
				cb: ()->{
					var copy = project.defs.pasteEntityDef(App.ME.clipboard);
					editor.ge.emit(EntityDefAdded);
					selectEntity(copy);
				},
				enable: ()->App.ME.clipboard.is(CEntityDef),
			}
		]);

		// Tags
		var tagGroups = project.defs.groupUsingTags(project.defs.entities, (ed)->ed.tags);
		for( group in tagGroups ) {
			// Tag name
			if( tagGroups.length>1 ) {
				var jSep = new J('<li class="title fixed"/>');
				jSep.text( group.tag==null ? L._Untagged() : group.tag );
				jSep.appendTo(jEntityList);

				// Rename
				if( group.tag!=null ) {
					var jLinks = new J('<div class="links"> <a> <span class="icon edit"></span> </a> </div>');
					jSep.append(jLinks);
					TagEditor.attachRenameAction( jLinks.find("a"), group.tag, (t)->{
						for(ed in project.defs.entities) {
							ed.tags.rename(group.tag, t);
							for(fd in ed.fieldDefs)
								fd.allowedRefTags.rename(group.tag, t);
						}
						for(ld in project.defs.layers) {
							ld.requiredTags.rename(group.tag, t);
							ld.excludedTags.rename(group.tag, t);
						}
						editor.ge.emit( EntityDefChanged );
					});
				}
			}

			// Create sub list
			var jLi = new J('<li class="subList"/>');
			jLi.appendTo(jEntityList);
			var jSubList = new J('<ul/>');
			jSubList.appendTo(jLi);

			for(ed in group.all) {
				var jEnt = new J('<li class="iconLeft"/>');
				jEnt.appendTo(jSubList);
				jEnt.attr("uid", ed.uid);

				// HTML entity display preview
				var preview = JsTools.createEntityPreview(editor.project, ed);
				preview.appendTo(jEnt);

				// Name
				jEnt.append('<span class="name">${ed.identifier}</span>');
				if( curEntity==ed ) {
					jEnt.addClass("active");
					jEnt.css( "background-color", C.intToHex( C.toWhite(ed.color, 0.5) ) );
				}
				else
					jEnt.css( "color", C.intToHex( C.toWhite(ed.color, 0.5) ) );

				// Menu
				ContextMenu.addTo(jEnt, [
					{
						label: L._Copy(),
						cb: ()->App.ME.clipboard.copyData(CEntityDef, ed.toJson(project)),
					},
					{
						label: L._Cut(),
						cb: ()->{
							App.ME.clipboard.copyData(CEntityDef, ed.toJson(project));
							deleteEntityDef(ed);
						},
					},
					{
						label: L._PasteAfter(),
						cb: ()->{
							var copy = project.defs.pasteEntityDef(App.ME.clipboard, ed);
							editor.ge.emit(EntityDefAdded);
							selectEntity(copy);
						},
						enable: ()->App.ME.clipboard.is(CEntityDef),
					},
					{
						label: L._Duplicate(),
						cb:()->{
							var copy = project.defs.duplicateEntityDef(ed);
							editor.ge.emit(EntityDefAdded);
							selectEntity(copy);
						}
					},
					{ label: L._Delete(), cb:deleteEntityDef.bind(ed) },
				]);

				// Click
				jEnt.click( function(_) selectEntity(ed) );
			}

			// Make sub list sortable
			JsTools.makeSortable(jSubList, function(ev:sortablejs.Sortable.SortableDragEvent) {
				var jItem = new J(ev.item);
				var fromIdx = project.defs.getEntityIndex( Std.parseInt( jItem.attr("uid") ) );
				var toIdx = ev.newIndex>ev.oldIndex
					? jItem.prev().length==0 ? 0 : project.defs.getEntityIndex( Std.parseInt( jItem.prev().attr("uid") ) )
					: jItem.next().length==0 ? project.defs.entities.length-1 : project.defs.getEntityIndex( Std.parseInt( jItem.next().attr("uid") ) );
				var moved = project.defs.sortEntityDef(fromIdx, toIdx);
				selectEntity(moved);
				editor.ge.emit(EntityDefSorted);
			});
		}

		checkBackup();
	}


	function updatePreview() {
		if( curEntity==null )
			return;

		jPreview.children(".entityPreview").remove();
		jPreview.append( JsTools.createEntityPreview(project, curEntity, 64) );
	}
}
