package components;

import components.EditorComponent;
import components.ActivateableComponent;
import luxe.Component;

class Load extends ActivateableComponent {
	override public function activate() {
		Main.instance.Load();
	}
}