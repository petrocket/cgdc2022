
#include <AzCore/Serialization/SerializeContext.h>
#include <AzCore/Serialization/EditContext.h>
#include <AzCore/Serialization/EditContextConstants.inl>

#include "cgdc2022SystemComponent.h"

namespace cgdc2022
{
    void cgdc2022SystemComponent::Reflect(AZ::ReflectContext* context)
    {
        if (AZ::SerializeContext* serialize = azrtti_cast<AZ::SerializeContext*>(context))
        {
            serialize->Class<cgdc2022SystemComponent, AZ::Component>()
                ->Version(0)
                ;

            if (AZ::EditContext* ec = serialize->GetEditContext())
            {
                ec->Class<cgdc2022SystemComponent>("cgdc2022", "[Description of functionality provided by this System Component]")
                    ->ClassElement(AZ::Edit::ClassElements::EditorData, "")
                        ->Attribute(AZ::Edit::Attributes::AppearsInAddComponentMenu, AZ_CRC("System"))
                        ->Attribute(AZ::Edit::Attributes::AutoExpand, true)
                    ;
            }
        }
    }

    void cgdc2022SystemComponent::GetProvidedServices(AZ::ComponentDescriptor::DependencyArrayType& provided)
    {
        provided.push_back(AZ_CRC("cgdc2022Service"));
    }

    void cgdc2022SystemComponent::GetIncompatibleServices(AZ::ComponentDescriptor::DependencyArrayType& incompatible)
    {
        incompatible.push_back(AZ_CRC("cgdc2022Service"));
    }

    void cgdc2022SystemComponent::GetRequiredServices([[maybe_unused]] AZ::ComponentDescriptor::DependencyArrayType& required)
    {
    }

    void cgdc2022SystemComponent::GetDependentServices([[maybe_unused]] AZ::ComponentDescriptor::DependencyArrayType& dependent)
    {
    }

    cgdc2022SystemComponent::cgdc2022SystemComponent()
    {
        if (cgdc2022Interface::Get() == nullptr)
        {
            cgdc2022Interface::Register(this);
        }
    }

    cgdc2022SystemComponent::~cgdc2022SystemComponent()
    {
        if (cgdc2022Interface::Get() == this)
        {
            cgdc2022Interface::Unregister(this);
        }
    }

    void cgdc2022SystemComponent::Init()
    {
    }

    void cgdc2022SystemComponent::Activate()
    {
        cgdc2022RequestBus::Handler::BusConnect();
    }

    void cgdc2022SystemComponent::Deactivate()
    {
        cgdc2022RequestBus::Handler::BusDisconnect();
    }
}
