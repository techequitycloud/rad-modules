import org.cyclos.entities.marketplace.Order
import org.cyclos.entities.system.ExtensionPoint
import org.cyclos.model.marketplace.webshoporders.OrderStatus
import org.cyclos.model.system.extensionpoints.ExtensionPointEvent

Map<String, Object> context = binding.context
ExtensionPointEvent event = binding.event
ExtensionPoint extensionPoint = binding.extensionPoint
OrderStatus newStatus = binding.newStatus
OrderStatus oldStatus = binding.oldStatus
Order order = binding.order
Boolean wasPendingByAdmin = binding.wasPendingByAdmin

throw new UnsupportedOperationException('Script not implemented')