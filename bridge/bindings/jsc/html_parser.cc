/*
 * Copyright (C) 2021 Alibaba Inc. All rights reserved.
 * Author: Kraken Team.
 */

#include "html_parser.h"
#include "bindings/jsc/DOM/text_node.h"
#include "third_party/gumbo-parser/src/gumbo.h"
#include <unordered_map>
#include <vector>

namespace kraken::binding::jsc {

std::unique_ptr<HTMLParser> createHTMLParser(std::unique_ptr<JSContext> &context, const JSExceptionHandler &handler, void *owner) {
  return std::make_unique<HTMLParser>(context, handler, owner);
}

HTMLParser::HTMLParser(std::unique_ptr<JSContext> &context, const JSExceptionHandler &handler, void *owner)
  : m_context(context), _handler(handler), owner(owner) {

}

void HTMLParser::splitStyle(std::string style) {

}

void HTMLParser::traverseHTML(GumboNode * node, ElementInstance* element) {
  const GumboVector* children = &node->v.element.children;
  for (int i = 0; i < children->length; ++i) {
    GumboNode* child = (GumboNode*) children->data[i];

    if (child->type == GUMBO_NODE_ELEMENT) {
      auto newElement = JSElement::buildElementInstance(m_context.get(), gumbo_normalized_tagname(child->v.element.tag));
      element->internalAppendChild(newElement);

      GumboVector* attributes = &child->v.element.attributes;
      for (int j = 0; j < attributes->length; ++j) {
        GumboAttribute* attribute = (GumboAttribute*) attributes->data[j];
//        KRAKEN_LOG(VERBOSE) << attribute->name;
//        KRAKEN_LOG(VERBOSE) << attribute->value;

        if (strcmp(attribute->name, "style") == 0) {
          std::vector<std::string> output;
          std::string::size_type prev_pos = 0, pos = 0;
          std::string styles = attribute->value;

          while((pos = styles.find(";", pos)) != std::string::npos)
          {
            std::string substring( styles.substr(prev_pos, pos-prev_pos) );

            std::string::size_type position = substring.find(":");
            if (position != substring.npos) {
              KRAKEN_LOG(VERBOSE) << substring.substr(0, position);
              KRAKEN_LOG(VERBOSE) << substring.substr(position + 1, substring.length());
            }

//            KRAKEN_LOG(VERBOSE) << substring;

            prev_pos = ++pos;
          }

//          KRAKEN_LOG(VERBOSE) << styles.substr(prev_pos, pos-prev_pos);

          JSStringRef propertyName = JSStringCreateWithUTF8CString("style");
          JSValueRef exc = nullptr; // exception
          JSValueRef styleRef = JSObjectGetProperty(m_context->context(), newElement->object, propertyName, &exc);
          JSObjectRef style = JSValueToObject(m_context->context(), styleRef, nullptr);
          auto styleDeclarationInstance = static_cast<StyleDeclarationInstance *>(JSObjectGetPrivate(style));
          std::string strTextAlign = "text-align";
          styleDeclarationInstance->internalSetProperty(strTextAlign, JSValueMakeString(m_context->context(),JSStringCreateWithUTF8CString("center")), nullptr);
        }
      }

      traverseHTML(child, newElement);
    } else if (child->type == GUMBO_NODE_TEXT) {
      auto newTextNodeInstance = new JSTextNode::TextNodeInstance(JSTextNode::instance(m_context.get()),
                                                                  JSStringCreateWithUTF8CString(child->v.text.text));
      element->internalAppendChild(newTextNodeInstance);
    }
  }
}

bool HTMLParser::parseHTML(const uint16_t *code, size_t codeLength) {
  ElementInstance* body;
  auto document = DocumentInstance::instance(m_context.get());
  for (int i = 0; i < document->documentElement->childNodes.size(); ++i) {
    NodeInstance* node = document->documentElement->childNodes[i];
    ElementInstance* element = reinterpret_cast<ElementInstance *>(node);


    if (element->tagName() == "BODY") {
      body = element;
      break;
    }
  }

  if (body != nullptr) {
    JSStringRef sourceRef = JSStringCreateWithCharacters(code, codeLength);

    std::string html = JSStringToStdString(sourceRef);

    int html_length = html.length();
    GumboOutput* output = gumbo_parse_with_options(
      &kGumboDefaultOptions, html.c_str(), html_length);

    const GumboVector *root_children = &output->root->v.element.children;

    for (int i = 0; i < root_children->length; ++i) {
      GumboNode* child =(GumboNode*) root_children->data[i];
      if (child->v.element.tag == GUMBO_TAG_BODY) {
        traverseHTML(child, body);
      }
    }

    JSStringRelease(sourceRef);
  } else {
    KRAKEN_LOG(ERROR) << "BODY is null.";
  }

  return true;
}

}


