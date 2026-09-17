// Entry do admin (layout "application"). Só ativa os módulos presentes na página via data-module.
//
// Trix/Action Text é a única lib de terceiros (decisão: editor da descrição do produto, spec 03/05);
// registra o custom element <trix-editor> e o upload de anexos do rich text.
import "trix";
import "@rails/actiontext";
import { activate } from "lib/modules";

activate();
