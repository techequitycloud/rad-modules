import java.lang.reflect.Method
import org.cyclos.entities.system.ServiceInterceptor
import org.cyclos.impl.system.ServiceInterceptorContext
import org.cyclos.services.Service

ServiceInterceptorContext context = binding.context
ServiceInterceptor interceptor = binding.interceptor
Method operation = binding.operation
Class service = binding.service

throw new UnsupportedOperationException('Script not implemented')