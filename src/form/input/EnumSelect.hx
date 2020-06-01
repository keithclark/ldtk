package form.input;

class EnumSelect<T> extends form.Input<T> {
	public var trimSpaces = true;
	var enumRef : Enum<T>;

	public function new(j:js.jquery.JQuery, e:Enum<T>, getter:Void->T, setter:T->Void) {
		super(j, getter, setter);
		enumRef = e;
		trace(enumRef);
		trace(getter());

		input.empty();
		for(k in Type.getEnumConstructs(enumRef)) {
			var t = enumRef.createByName(k);
			var opt = new J("<option>");
			input.append(opt);
			opt.attr("value",k);
			opt.text(k);
			if( t==getter() )
				opt.attr("selected","selected");
	}
	}

	override function parseFormValue() : T {
		var v = input.val();
		return enumRef.createByName( input.val() );
	}
}
